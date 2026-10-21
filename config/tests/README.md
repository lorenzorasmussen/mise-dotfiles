# Hook fixture tests

`opencode-post-update-test.sh` exercises the OpenCode post-update repair hook
and the `opencode-integrity` program against a throwaway tree, and asserts what
a consumer can observe: exit status, messages, and the bytes of the wrapper.

```sh
bash tests/opencode-post-update-test.sh
```

Exit code 0 means every assertion passed; anything else prints the failures.

## Why the fixture uses bwrap

Both programs address **fixed absolute paths** on purpose — the hook runs from
an Omarchy post-update hook, so nothing in the environment may redirect what it
checks or what it repairs. There is therefore no override variable to point
them at a scratch tree. Instead the fixture reproduces the live layout inside
an ephemeral mount namespace (bwrap):

| Path in the namespace | Comes from |
|---|---|
| `/home/lorenzo/.local/bin` | the fixture: the wrapper, a mise stub, a copy of `opencode-integrity`, a stub runtime |
| `/home/lorenzo/.config/mise/opencode-wrapper` | the fixture template |
| `/tmp/fixture-home/.config/omarchy/hooks` | a copy of `hooks/opencode-post-update` |
| `/tmp` | a fresh tmpfs — the default scratch area for the checker |
| everything else | the host, read-only |

`bwrap` and user namespaces are required. The host tree is read-only inside
the namespace, so a stray write fails instead of reaching the live wrapper.

## Mount-layout rules (learned the hard way)

- **A mount point must already exist in the host tree.** On the read-only root
  bwrap cannot create one: `--dir /fixture-home/.config/omarchy/hooks` fails
  with `Can't mkdir parents for /fixture-home/.config/omarchy/hooks: Read-only
  file system`. Put every writable fixture root under a tmpfs that already
  exists — `/tmp` is the one that always does — and mount the fixture home
  there (`HOME=/tmp/fixture-home`).
- **Bind a directory, not a file, for anything the program rewrites.**
  `install` cannot replace a file that is itself a bind-mount point
  (`Device or resource busy`), so `~/.local/bin` is the bind and the wrapper
  is a member of it.
- **The scratch file is the default, not a requirement.** The integrity program
  keeps mise's diagnostics in a scratch file when it can create one, and falls
  back to letting mise write to stderr when it cannot. The default variant
  therefore gives it a writable `/tmp`, so the scratch-file branch is the one
  under test; the `ro-scratch` variant points `TMPDIR` at a read-only
  directory to cover the fallback branch. The two branches are told apart by
  the failure line: with a scratch file it carries the reason
  (`failed (exit 1): <reason>`), without one it falls back to the short form
  (`failed (exit 1)`) while mise's own reason still reaches stderr.
- **Each variant asserts its own precondition.** The harness probes the
  namespace and requires `home=writable` in every variant, `scratch=writable`
  in the default variant and `scratch=readonly` in the `ro-scratch` variant,
  so a layout change cannot silently stop testing what it claims to test.

## What it asserts

1. healthy dispatch through the real `/usr/bin/omarchy-hook post-update`;
2. a drifted wrapper is repaired, bytes and mode 0755 restored;
3. a missing wrapper is recreated from the template;
4. a missing integrity program → exit 127, named, and no repair performed;
5. a non-executable integrity program → exit 126, named;
5b. every variant's precondition: the fixture root is writable in all four
   variants, the scratch area writable in the default variant and read-only in
   the `ro-scratch` variant;
6. a version the host does not pin → exit 1, both versions named;
7. mise itself failing → exit 1, the reason visible and carried in the failure
   line, and never reported as an empty version;
7c. the same with no writable scratch file available → still exit 1, the reason
   still visible, the failing command still named, and the failure line in its
   short form (the branch that proves no scratch file was used);
8. mise resolving an executable that is not there → exit 1, named;
9. without `--repair` the program reports the drift and writes nothing;
10. the Omarchy runner prints `Hook failed:` and still exits 0;
11. the live tree, the mise trust store and the tracked-config list are
    unchanged by the run.

## Before/after comparison

The harness runs against any source tree, which is how the pre-patch behaviour
was recorded:

```sh
bash tests/opencode-post-update-test.sh --source /home/lorenzo/.config/mise
```

The unpatched source fails 8 of the 53 assertions, and they are all one
behaviour: a failing mise that still printed a version was reported as
healthy, and a failing mise that printed nothing was reported as
`mise selects ''` with the real reason discarded — with and without a scratch
file.
