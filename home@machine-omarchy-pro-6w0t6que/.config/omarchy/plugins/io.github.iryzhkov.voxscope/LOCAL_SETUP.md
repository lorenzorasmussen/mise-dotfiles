# Lorenzo's compact bottom HUD

This installed Voxscope checkout is locally customized on branch
`codex/voxscope-small-bottom`.

The current Omarchy shell gives third-party plugins a scoped API without
`shellConfig`. Upstream `Hud.qml` therefore reads default `compact=false` and
`position="center"` even when those values appear in `shell.json`. This local
`Hud.qml` sets `compact=true` and `position="bottom"` directly. `Card.qml` sets
the compact card to 480 × 140. Restart Omarchy shell after editing either file:
`omarchy restart shell`. Hot reload alone did not replace the loaded HUD during
the 2026-10-29 check.

Measured without recording audio: setting Voxtype's state file temporarily to
`transcribing` produced a Voxscope layer at x=744, y=1036, 560 × 220 on the
2048 × 1280 screen; the state was restored to `idle` afterward. The window is
24 pixels from the bottom. The complete F9 dictation setup is documented at
`~/.config/voxtype/README.md`.

Omarchy's normal update does not replace this user-owned checkout. Its plugin
update uses a fast-forward merge and refuses divergent local changes. Review
and rebase this branch before taking a future upstream Voxscope update.

Official reference: https://omarchy.org/manual/shell-plugins/
