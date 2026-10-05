-- Backend plugin metadata.
--
-- Why this plugin exists: mise has no zsh in any registry. Measured 2026-10-06
-- on mise 2026.10.2:
--   * `zsh` is not in `mise registry` (not a core language, no aqua entry).
--   * zsh publishes Git tags but NO GitHub release assets, so mise's generic
--     `github:` backend cannot install it ("no versions found").
--   * There is no `aqua:zsh-users/zsh`, no `vfox:mise-plugins/vfox-zsh`, and no
--     asdf zsh plugin (`mise-plugins/asdf-zsh` 404s). `mise use --dry-run`
--     still prints "would install" for all of these, so a dry run is NOT a
--     validity check for a registry-backed backend -- `mise ls-remote` is.
--
-- The alternative was `omarchy pkg add zsh`, which needs a sudo password this
-- agent cannot supply unattended. Building from source keeps zsh under mise,
-- which is what the user asked for.
--
-- Docs: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = {
    name = "zsh-src",
    version = "1.0.0",
    description = "Builds zsh from the official source tarball (no release assets)",
    author = "lorenzo",
    homepage = "https://github.com/zsh-users/zsh",
    license = "MIT-like (zsh)",
    notes = {
        "Requires a C toolchain and autoconf on PATH",
        "Builds from source: autoconf + configure + make",
    },
}