#!/bin/bash
# Fixture harness for the OpenCode post-update repair hook.
#
# Exercises the real hook (hooks/opencode-post-update) and the real integrity
# program (opencode-integrity) against a throwaway tree and asserts what a
# consumer can observe: exit status, messages, and the bytes of the wrapper.
# The live Omarchy hook is never invoked, the live wrapper is never written,
# and nothing outside the temporary fixture is modified.
#
#   bash tests/opencode-post-update-test.sh                # the patched source
#   bash tests/opencode-post-update-test.sh --source <dir>  # another source tree
#
# The shipped programs address fixed absolute paths on purpose, so the fixture
# is bind-mounted at exactly those paths inside an ephemeral mount namespace
# (bwrap): ~/.local/bin holds the wrapper, the mise stub and the integrity
# program, ~/.config/mise holds the wrapper template, and $HOME holds the Omarchy
# hook directory. The rest of the host stays read-only, so a stray write fails
# instead of reaching the live tree. Needs user namespaces.
#
# The same harness runs against an unpatched source tree, which is how the
# before/after comparison was produced.

set -u

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root"

while (( $# )); do
  case "$1" in
    --source) source_dir="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

hook_src="$source_dir/hooks/opencode-post-update"
integrity_src="$source_dir/opencode-integrity"

if [[ ! -f $hook_src || ! -f $integrity_src ]]; then
  echo "source tree incomplete: $hook_src / $integrity_src" >&2
  exit 64
fi

if ! command -v bwrap >/dev/null; then
  echo "bwrap is required: the fixture binds the tree at the fixed absolute paths" >&2
  exit 64
fi

# A patched hook names the missing program; an unpatched one lets bash say it.
hook_patched="no"
grep -q 'FAIL: opencode-integrity is missing' "$hook_src" && hook_patched="yes"

failures=0
ok() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }

assert_rc() {
  if [[ $1 == "$2" ]]; then ok "$3 (exit $2)"; else bad "$3: expected exit $1, got $2"; fi
}
assert_contains() {
  if [[ $1 == *"$2"* ]]; then ok "$3"; else bad "$3: output lacked [$2]"; printf '     output: %s\n' "$1" >&2; fi
}
assert_lacks() {
  if [[ $1 != *"$2"* ]]; then ok "$3"; else bad "$3: output wrongly contained [$2]"; fi
}
assert_same_file() {
  if cmp -s "$1" "$2"; then ok "$3"; else bad "$3: $1 differs from $2"; fi
}
assert_mode() {
  local mode
  mode="$(stat -c '%a' "$1" 2>/dev/null)"
  if [[ $mode == "$2" ]]; then ok "$3 (mode $mode)"; else bad "$3: expected mode $2, got ${mode:-none}"; fi
}

fixture="$(mktemp -d "${TMPDIR:-/tmp}/opencode-hook-fixture.XXXXXX")"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT

hostbin="$fixture/hostbin"
emptybin="$fixture/emptybin"
nonexecbin="$fixture/nonexecbin"
omarchy_hooks="$fixture/omarchy-hooks"
wrapper="$hostbin/opencode"
template="$fixture/opencode-wrapper"
stub_mise="$hostbin/mise"
stub_opencode="$hostbin/opencode-runtime"

mkdir -p "$hostbin" "$emptybin" "$nonexecbin" "$omarchy_hooks/post-update.d"

cat > "$template" <<'TEMPLATE'
#!/bin/bash
exec /home/lorenzo/.local/bin/mise x "opencode@2.0.29" -- opencode "$@"
TEMPLATE
chmod 0755 "$template"

cat > "$stub_mise" <<'STUB'
#!/bin/bash
case "${1:-} ${2:-}" in
  "current opencode")
    if [[ -n ${STUB_MISE_CURRENT_ERR:-} ]]; then printf '%s\n' "$STUB_MISE_CURRENT_ERR" >&2; fi
    printf '%s\n' "${STUB_MISE_CURRENT_OUT-2.0.29}"
    exit "${STUB_MISE_CURRENT_RC:-0}"
    ;;
  "which opencode")
    if [[ -n ${STUB_MISE_WHICH_ERR:-} ]]; then printf '%s\n' "$STUB_MISE_WHICH_ERR" >&2; fi
    printf '%s\n' "${STUB_MISE_WHICH_OUT-}"
    exit "${STUB_MISE_WHICH_RC:-0}"
    ;;
  *)
    echo "stub mise: unsupported command: $*" >&2
    exit 64
    ;;
esac
STUB
chmod 0755 "$stub_mise"

cat > "$stub_opencode" <<'STUB'
#!/bin/bash
if [[ ${1:-} == --version ]]; then
  echo "opencode v${STUB_OPENCODE_VERSION-2.0.29}"
  exit 0
fi
exit 0
STUB
chmod 0755 "$stub_opencode"

install -m 0755 "$integrity_src" "$hostbin/opencode-integrity"
install -m 0755 "$hook_src" "$omarchy_hooks/post-update.d/opencode-post-update"
if ! cmp -s "$integrity_src" "$hostbin/opencode-integrity"; then
  echo "integrity copy in the fixture does not match $integrity_src" >&2
  exit 1
fi
if ! cmp -s "$hook_src" "$omarchy_hooks/post-update.d/opencode-post-update"; then
  echo "hook copy in the fixture does not match $hook_src" >&2
  exit 1
fi

: > "$nonexecbin/opencode-integrity"
chmod 0644 "$nonexecbin/opencode-integrity"

# The live tree must not change while the fixture runs.
live_watch=(
  /home/lorenzo/.local/bin/opencode
  /home/lorenzo/.local/bin/opencode-integrity
  /home/lorenzo/.config/mise/opencode-wrapper
  /home/lorenzo/.config/mise/opencode-integrity
  /home/lorenzo/.config/omarchy/hooks/post-update.d/opencode-post-update
  /home/lorenzo/.mise.toml
  /home/lorenzo/.config/mise/config.toml
)
live_state() {
  for f in "${live_watch[@]}"; do
    if [[ -e $f ]]; then printf '%s %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"
    else printf 'absent %s\n' "$f"; fi
  done
  ls -1 /home/lorenzo/.local/state/mise/trusted-configs 2>/dev/null | sort
  ls -1 /home/lorenzo/.local/state/mise/tracked-configs 2>/dev/null | sort
}
before_state="$(live_state)"

write_wrapper() { printf '%s\n' "$1" > "$wrapper"; chmod 0755 "$wrapper"; }
write_healthy_wrapper() { install -m 0755 "$template" "$wrapper"; }

rc=0
out=""

# The namespace mirrors the live layout: the fixed absolute paths the programs
# use, an Omarchy hook directory under HOME, and a writable scratch directory.
namespace=(
  --ro-bind / /
  --dev /dev
  --proc /proc
  --tmpfs /tmp
  --tmpfs /home/lorenzo/.config/mise
  --dir /tmp/fixture-home/.config/omarchy/hooks
  --unshare-user
  --unshare-pid
  --unshare-ipc
  --unshare-uts
  --die-with-parent
  --setenv HOME /tmp/fixture-home
)

# The resolved executable lives inside the namespace at a fixed path; a case
# may point mise somewhere else to model a missing runtime.
resolved_default="/home/lorenzo/.local/bin/opencode-runtime"

run_namespace() {
  # run_namespace <variant> <command...> - variant: normal | hide-bin | nonexec-bin
  local variant="$1"
  shift
  local args=(
    "${namespace[@]}"
    --ro-bind "$template" /home/lorenzo/.config/mise/opencode-wrapper
    --bind "$omarchy_hooks" /tmp/fixture-home/.config/omarchy/hooks
    --setenv STUB_MISE_WHICH_OUT "${STUB_MISE_WHICH_OUT:-$resolved_default}"
  )
  case "$variant" in
    normal)
      args+=( --bind "$hostbin" /home/lorenzo/.local/bin )
      ;;
    ro-scratch)
      # no writable scratch file: the checker must still report mise's reason
      args+=( --bind "$hostbin" /home/lorenzo/.local/bin --setenv TMPDIR /home/lorenzo/.config )
      ;;
    hide-bin)
      # ~/.local/bin is empty, so the program the hook dispatches to is missing
      args+=( --bind "$emptybin" /home/lorenzo/.local/bin )
      ;;
    nonexec-bin)
      args+=( --bind "$nonexecbin" /home/lorenzo/.local/bin )
      ;;
  esac
  out="$(bwrap "${args[@]}" "$@" 2>&1)"
  rc=$?
}

probe_scratch() {
  # probe_scratch <variant> - reports whether the scratch area and the fixture
  # root are usable inside the namespace
  run_namespace "$1" bash -c 'if mktemp >/dev/null 2>&1; then s=writable; else s=readonly; fi
if : > "$HOME/.probe" 2>/dev/null; then h=writable; rm -f "$HOME/.probe"; else h=readonly; fi
echo "scratch=$s home=$h"'
}

run_hook() {
  # run_hook <variant> - dispatch the hook the way the Omarchy runner does
  run_namespace "$1" bash /tmp/fixture-home/.config/omarchy/hooks/post-update.d/opencode-post-update
}

run_hook_via_omarchy() {
  run_namespace normal omarchy-hook post-update
}

run_integrity_no_repair() {
  run_namespace normal bash /home/lorenzo/.local/bin/opencode-integrity
}

printf '== source: %s\n== fixture: bwrap namespace at the fixed absolute paths\n' "$source_dir"

# 1. healthy dispatch through the real Omarchy runner
write_healthy_wrapper
run_hook_via_omarchy
assert_rc 0 "$rc" "healthy dispatch through omarchy-hook"
assert_contains "$out" "OK: OpenCode 2.0.29 is pinned and healthy" "healthy dispatch reports the pinned runtime"
assert_lacks "$out" "Repaired:" "healthy dispatch does not claim a repair"
assert_same_file "$wrapper" "$template" "healthy dispatch leaves the wrapper bytes alone"

# 2. repair a drifted wrapper
write_wrapper "# drifted wrapper"
run_hook normal
assert_rc 0 "$rc" "repair of a drifted wrapper"
assert_contains "$out" "Repaired:" "repair reports what it repaired"
assert_same_file "$wrapper" "$template" "repair restores the wrapper bytes"
assert_mode "$wrapper" 755 "repair restores the wrapper mode"

# 3. repair a missing wrapper
rm -f "$wrapper"
run_hook normal
assert_rc 0 "$rc" "repair of a missing wrapper"
assert_contains "$out" "Repaired:" "missing-wrapper repair is reported"
assert_same_file "$wrapper" "$template" "missing wrapper is recreated from the template"
assert_mode "$wrapper" 755 "recreated wrapper is executable"

# 4. the integrity program is missing
write_wrapper "# drifted wrapper"
run_hook hide-bin
assert_rc 127 "$rc" "missing integrity program"
assert_contains "$out" "opencode-integrity" "missing integrity program is named in the output"
assert_same_file "$wrapper" <(printf '# drifted wrapper\n') "missing integrity program repairs nothing"
if [[ $hook_patched == yes ]]; then
  assert_contains "$out" "FAIL: opencode-integrity is missing" "missing integrity program is reported as a failure"
fi

# 5. the integrity program is not executable
write_wrapper "# drifted wrapper"
run_hook nonexec-bin
assert_rc 126 "$rc" "non-executable integrity program"
assert_contains "$out" "opencode-integrity" "non-executable integrity program is named in the output"
if [[ $hook_patched == yes ]]; then
  assert_contains "$out" "FAIL: opencode-integrity is not executable" "non-executable integrity program is reported as a failure"
fi

# 5b. every variant really does have a writable fixture root, and the default
# variant really does have a writable scratch area
for variant in normal ro-scratch hide-bin nonexec-bin; do
  probe_scratch "$variant"
  assert_rc 0 "$rc" "the scratch probe runs in the $variant variant"
  assert_contains "$out" "home=writable" "the fixture root is writable in the $variant variant"
done

probe_scratch normal
assert_contains "$out" "scratch=writable" "the default variant has a writable scratch area"

# 6. a version the host does not pin fails the check
STUB_MISE_CURRENT_OUT=2.0.30 run_hook normal
assert_rc 1 "$rc" "version drift fails the check"
assert_contains "$out" "FAIL: mise selects '2.0.30', expected '2.0.29'" "version drift names both versions"

# 7. mise itself failing reports the reason, not an empty version
STUB_MISE_CURRENT_RC=1 STUB_MISE_CURRENT_ERR="mise ERROR: config file is not trusted" run_hook normal
assert_rc 1 "$rc" "a failing mise command fails the check"
assert_contains "$out" "not trusted" "the reason mise gave is visible in the output"
assert_contains "$out" "failed (exit 1): mise ERROR: config file is not trusted" "the failure line carries the reason (scratch file used)"
assert_lacks "$out" "mise selects ''" "the empty version is not reported as a version"

# 7b. mise fails and prints nothing on stdout
STUB_MISE_CURRENT_RC=1 STUB_MISE_CURRENT_OUT= STUB_MISE_CURRENT_ERR="mise ERROR: config file is not trusted" run_hook normal
assert_rc 1 "$rc" "a failing mise command with no output still fails the check"
assert_contains "$out" "not trusted" "the reason is visible when mise printed nothing"
assert_lacks "$out" "mise selects ''" "an empty version is not reported as a version"

# 7c. mise fails and no scratch file is available
probe_scratch ro-scratch
assert_rc 0 "$rc" "the scratch probe runs without a scratch file"
assert_contains "$out" "scratch=readonly" "the no-scratch variant really has a read-only scratch area"

STUB_MISE_CURRENT_RC=1 STUB_MISE_CURRENT_ERR="mise ERROR: config file is not trusted" run_hook ro-scratch
assert_rc 1 "$rc" "a failing mise command fails the check without a scratch file"
assert_contains "$out" "not trusted" "the reason is visible without a scratch file"
assert_contains "$out" "mise current opencode failed (exit 1)" "the failing command is named without a scratch file"
assert_lacks "$out" "failed (exit 1): mise ERROR" "the failure line falls back to the short form without a scratch file"
assert_lacks "$out" "mise selects ''" "the empty version is not reported as a version without a scratch file"

# 8. mise resolving an executable that is not there
STUB_MISE_WHICH_OUT=/nonexistent/opencode run_hook normal
assert_rc 1 "$rc" "a missing resolved executable fails the check"
assert_contains "$out" "mise resolved a missing executable" "the missing resolved executable is named"

# 9. without --repair the check never writes the wrapper
write_wrapper "# drifted wrapper"
run_integrity_no_repair
assert_rc 1 "$rc" "the check without --repair reports the drift"
assert_contains "$out" "FAIL: wrapper differs from" "the check without --repair names the drift"
assert_same_file "$wrapper" <(printf '# drifted wrapper\n') "the check without --repair writes nothing"

# 10. the runner swallows a failed hook but says so
STUB_MISE_CURRENT_OUT=2.0.30 run_hook_via_omarchy
assert_rc 0 "$rc" "omarchy-hook exits 0 when the hook fails (upstream runner behaviour)"
assert_contains "$out" "Hook failed:" "the runner reports the failed hook"
assert_contains "$out" "FAIL: mise selects '2.0.30'" "the failure reason survives the runner"

# 11. nothing on the live tree changed
after_state="$(live_state)"
if [[ $before_state == "$after_state" ]]; then
  ok "the live tree, the mise trust store and the tracked configs are unchanged"
else
  bad "the live tree changed during the fixture run"
  diff <(printf '%s\n' "$before_state") <(printf '%s\n' "$after_state") >&2 || true
fi

rm -rf "$fixture"
trap - EXIT

if (( failures > 0 )); then
  printf '\n%d assertion(s) failed\n' "$failures" >&2
  exit 1
fi
printf '\nall assertions passed\n'
