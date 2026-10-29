# F9 dictation on this Omarchy laptop

Last verified: 2026-10-29. This is the setup for this machine (four CPU cores,
7.6 GiB RAM, Danish keyboard). It is intentionally local speech recognition
with optional remote **text-only** cleanup.

## Active path

1. Hold F9 to record; release to transcribe. Hyprland handles the key.
2. Voxtype uses the local `parakeet-tdt-0.6b-v3-int8` model with eager
   processing. `parakeet.streaming = false`; text appears after F9 is released.
3. `[output.post_process]` runs `~/.local/bin/voxtype-free-clean`. It reads the
   existing OpenRouter key from `~/.local/share/opencode/auth.json` at runtime.
   The script sends only the transcript, never audio, and never prints the key.
4. OpenRouter tries these explicitly free models in order:
   `nvidia/nemotron-3.5-super-vl:free`,
   `poolside/laguna-xs-2.1:free`, `poolside/laguna-s-2.1:free`.
   All three had zero prompt and completion price in the live model catalog on
   2026-10-29. There is no paid fallback.
5. If a provider fails, OpenRouter tries the next model. If the account's
   free quota is exhausted, the API fails, or the response is rejected,
   the script emits the original transcript. Voxtype also falls back to the
   original on command failure or timeout. The HTTP request has a six-second
   timeout; Voxtype's post-process cap is seven seconds.
6. Voxtype types via `wtype`, with `type_delay_ms = 0`. The F9 recording cap is
   120 seconds. The script accepts up to 64 KiB of text and requests at most
   2,048 output tokens; incomplete output falls back to the original.

The free-tier quota is controlled by OpenRouter. Its published general limits
are 20 requests/minute and 50/day for `:free` models, or 1,000/day once the
account qualifies; failed requests count. A quota hit cannot be fixed by
switching models on the same account. Dictation still works without cleanup.

## HUD and background services

Voxscope is the listening/transcribing display. Its user-installed source is
`~/.config/omarchy/plugins/io.github.iryzhkov.voxscope/`. On this Omarchy
version, third-party plugins receive a scoped shell interface without
`shellConfig`, so Voxscope's upstream setting reader falls back to its large,
centered defaults. The local `Hud.qml` therefore sets `compact = true` and
`position = "bottom"`; `Card.qml` sets the compact card to 480 × 140.
The resulting layer window was measured at 560 × 220, x=744, y=1036 on the
2048 × 1280 display (24 pixels from the bottom). After QML edits, run
`omarchy restart shell` because hot reload alone did not replace the loaded
HUD in our test. Voxtype's built-in OSD is disabled.

Tidy was disabled because F9 now cleans text automatically. The earlier local
Ollama cleanup service (`ollama-local.service`) is disabled and stopped to save
resources. The downloaded local models were left in place.

## Checks and recovery

```sh
voxtype status
voxtype setup check
voxtype config get output.post_process.command
systemctl --user is-active voxtype.service
omarchy plugin list --json
printf 'i has a test sentence' | ~/.local/bin/voxtype-free-clean
```

The sample command sends that sample text to OpenRouter. It may print the
unchanged input when a free provider or account quota is unavailable. The
status at `$XDG_RUNTIME_DIR/voxtype/postprocess.json` records a reason but no
transcript or credential. For logs: `journalctl --user -u voxtype.service -n 50`.

Configuration backups from this work are under
`~/.local/state/voxtype-automatic-cleanup-backup-20261029-final/`.
Voxscope custom code is committed on branch `codex/voxscope-small-bottom` in
its own Git checkout. `mise dot` tracks the active config and script and saves
them in local Git history. Normal `omarchy update` replaces packaged files in
`/usr/share/omarchy/`, not these user files. `omarchy plugin update` uses a
fast-forward merge and refuses to overwrite divergent local changes; to take
a future upstream Voxscope update, review/rebase this branch and retest the HUD.

## Official references

- [Voxtype configuration: post-processing and fallback](https://github.com/peteonrails/voxtype/blob/dev/docs/CONFIGURATION.md#outputpost_process)
- [Voxtype configuration: eager processing](https://github.com/peteonrails/voxtype/blob/dev/docs/CONFIGURATION.md#eager_processing)
- [OpenRouter model fallback](https://openrouter.ai/docs/guides/routing/model-fallbacks)
- [OpenRouter free-model limits](https://openrouter.ai/collections/free-models)
- [Omarchy shell plugins and update behavior](https://omarchy.org/manual/shell-plugins/)
- [mise dotfiles history](https://mise.jdx.dev/dotfiles/history.html)
