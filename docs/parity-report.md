# Kubuntu/Plasma 6 AI Port Parity Report

Report timestamp: 2026-08-28T02:05:06+03:00.

## Scope and pinned sources

This report covers the Kubuntu/Plasma 6 adapter in `kubuntu/` for Omarchy quattro commit `946704f30950576731d91a732b743f7c7fa8b188` and Hermes Harness main commit `2d7268800ee36eb36ba837c9755ebb3536f73d62`.

The source contract contains 85 Omarchy AI-related paths and all 12 pinned Hermes Harness files. The port does not replace Kubuntu's package database, Plasma system files, or another Hermes profile.

## Proven behavior

- Safe-I/O reads reject symlinks, enforce byte limits, bound subprocess execution, and clean up timed-out process groups.
- Hermes status exposes installation/version, gateway state, model/session telemetry, node telemetry, and bounded usage-record fallback.
- The agent launcher preserves all ten pinned command vectors: `pi`, `omp`, `opencode`, `ori`, `claude`, `codex`, `grok`, `agy`, `copilot`, and `crush`. Inline, terminal, prompt, and picker paths are covered.
- Claude, Codex, and Fireworks usage collectors preserve bounded JSON records, atomic writes, filtering, limits-only behavior, cache behavior, and aggregation.
- Crash watch preserves current-user filtering, executable identity, deduplication, per-program mute, global capture toggle, KDE notification action arguments, and the diagnose-crash skill boundary.
- Agent skills link idempotently into `.agents`, `.claude`, `.codex`, `.pi`, and `.gemini` target families.
- Claude, Pi, and OpenCode theme files sync atomically from `~/.local/state/omarchy/current/theme`; activation preserves unrelated settings. `omarchy theme refresh` fans out to all three adapters.
- ChatGPT Desktop, LM Studio, Ollama, T3 Code, and Grok Bot installer/remover surfaces retain dry-run-by-default, official-source, checksum, and explicit-apply boundaries. Grok Bot remains an explicit unavailable feature; no unofficial package is substituted.
- Voxtype config, status, model, install/remove boundaries, and KDE shortcut mapping are present. OCR remains an explicit gap below.
- Hermes Harness and Omarchy Agents are valid Plasma 6 packages and install through `kpackagetool6`.
- The live user-local install is present under `~/.local/share/omarchy-kubuntu-ai`. The runtime manifest contains 72 files, 42 command links, 1 owned KDE config stanza, and 2 Plasma packages. No generated Python bytecode is in the payload.

## Automated verification

The final Kubuntu-focused run passed:

- 22 Kubuntu shell tests: all passed.
- 9 Python tests across `kubuntu/tests` and `tests/kubuntu`: all passed.
- Bash syntax checks for Kubuntu shell entry points: passed.
- Python compilation checks for the safe-I/O and usage collector entry points: passed.
- `git diff --check`: passed at each completed change checkpoint.

The upstream aggregate `./test/all` was also exercised. `test/cli` passed. `test/shell` reported 17 host-dependent failures out of 206 files, all outside the Kubuntu port surface, including missing `lua`, missing `omarchy-pkgs` checkout data, and Hyprland/package-environment assumptions. Those failures are recorded as environment warnings, not silently counted as port passes.

## Live Plasma verification

Both packages are registered in the live Plasma user package store:

- `com.asmoday.omarchy.hermes-harness` — Hermes Harness.
- `com.asmoday.omarchy.agents` — Omarchy Agents.

The widgets were added to the top Plasma panel. Plasma scripting reported 32x32 geometry at x=1834 and x=1870 with no overlap. A native full-screen capture showed both compact glyphs rendered distinctly.

Standalone Plasma host captures verified the expanded surfaces without relying on an empty desktop capture:

- Hermes Harness: real version `Hermes Agent v0.20.6 (2026.8.27)`, gateway `active`, model fallback `unknown`, session fallback `none`, and `hermes-node unavailable`; `Refresh` and `Open Hermes` were visible and legible.
- Omarchy Agents: fixture-backed Claude/Pro view rendered limits, tokens by day, tokens by model, `Next`, `Refresh`, and `Launch agent` without clipping or overlap.
- Provider switching changed the view from Claude/Pro to Codex/Plus with the second fixture's limit and token data.
- The launch button was verified against a disposable shim and preserved `omarchy-agent --pick`.

Local evidence captures from this run:

- `/tmp/omarchy-kubuntu-qa-compact.png`
- `/tmp/omarchy-kubuntu-qa-hermes-xcb.png`
- `/tmp/omarchy-kubuntu-qa-hermes-refresh.png`
- `/tmp/omarchy-kubuntu-qa-agents-fixture.png`
- `/tmp/omarchy-kubuntu-qa-agents-next.png`

## Kubuntu host mappings

- Omarchy/Quickshell status surfaces map to Plasma 6 `PlasmoidItem` compact/full representations.
- Omarchy terminal launch maps to Konsole through `kubuntu-agent-terminal`, preserving CWD and argv.
- Omarchy notification actions map to KDE notifications with explicit action argv handling.
- Omarchy user services map to `systemd --user` units and a 15-minute usage timer.
- The global agent shortcut maps to a hidden application desktop entry plus a Plasma 6 `~/.local/share/kglobalaccel/omarchy-agent.desktop` service entry and `[services][omarchy-agent.desktop]` config stanza.
- No `/usr`, `/etc`, `/usr/share/omarchy`, package-managed Omarchy files, credentials, or Hermes profile secrets were modified.

## Explicit gaps and blockers

### OCR capture

`omarchy capture text` returns exit status `2` with an explicit unsupported message. The pinned source depends on the Hyprland `slurp`/`grim` selection pipeline. No verified Spectacle/KDE OCR adapter exists in this port, and no alternate application is silently substituted.

### Grok Bot artifact

No authoritative Linux artifact was confirmed for Grok Bot. The wrapper reports the feature as unsupported instead of installing an unofficial repack.

### Current-session global shortcut activation

The installed desktop files and exact Plasma 6 config stanza are verified. A live keypress pass is not claimed: this Plasma session's KWin process owns the `org.kde.kglobalaccel` bus name and was started before the new service entry was installed; the daemon API reports `NoSuchComponent` until the session reloads the service registry. Re-login or a controlled Plasma session restart is required to prove the keypress and launcher execution. The installer test covers fresh install, legacy-stanza migration, collision refusal, owned upgrade, unrelated-stanza preservation, and uninstall rollback.

### Computer-use bridge

`hermes computer-use doctor` passed the cua-driver binary, X11 reachability, AT-SPI, and screen capture checks. `computer_use list_windows` still returned zero windows because the active desktop is Wayland and the native Wayland backend is not enabled. Visual evidence was therefore captured with Spectacle and a temporary XCB Plasma host. No screenshot-based `computer_use` pass is claimed.

## Release decision

The Kubuntu-focused code and install tests are green, the payload and manifest are source-backed, and the Plasma surfaces have visual evidence. Release/PR remains blocked until a fresh Plasma session proves `Meta+Shift+Ctrl+A` end to end and the owner decides whether the explicit OCR gap is acceptable for the release scope. The upstream host-dependent failures remain warnings unless the project requires a fully provisioned Omarchy development host.
