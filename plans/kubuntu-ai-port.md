# Kubuntu AI Port Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task. Delegate implementation slices to the `coder` fleet worker after the source contract is frozen; keep source review and final parity approval in the parent lane.

**Goal:** Port the pinned Omarchy AI feature layer and the pinned Hermes Harness plugin to Kubuntu/Plasma 6 while preserving source behavior, schemas, command semantics, security boundaries, and visible interactions.

**Architecture:** Keep the upstream Omarchy and Hermes Harness checkouts intact. Build a Kubuntu adapter layer for package installation, Konsole launching, KDE notifications, Plasma global shortcuts, user systemd units, and Plasma 6 widgets. Preserve source-independent scripts and data contracts wherever possible. Keep the Omarchy Agents surface and Hermes Harness surface as separate widgets because they are separate upstream components.

**Tech Stack:** Bash 5, Python 3, jq, systemd user units, mise, KDE Plasma 6 QML/Plasmoid, Konsole, D-Bus/libnotify, apt/vendor Linux installers where source-backed, shell fixture tests, Plasma package validation.

---

## Source Baseline

- Omarchy fork: `https://github.com/asmodaydoescoding/omarchy`, upstream `https://github.com/basecamp/omarchy`, branch `quattro`, pinned commit `946704f30950576731d91a732b743f7c7fa8b188`.
- Hermes Harness fork: `https://github.com/asmodaydoescoding/omarchy-hermes-harness`, upstream `https://github.com/archer-clawbot/omarchy-hermes-harness`, branch `main`, pinned commit `2d7268800ee36eb36ba837c9755ebb3536f73d62`.
- Both upstreams are MIT licensed.
- The current source host is Ubuntu 26.04, KDE Plasma 6.6.6, Wayland, amd64. Git, gh, Python 3, jq, systemd, Konsole, KDE notifications, coredumpctl, and kpackagetool6 are installed. mise and standalone QML tooling are not installed.
- The pinned Omarchy executable source is authoritative over rendered manual drift. In particular, the source supports `agy` and `ori` while some public documentation still says `gemini`.

## Verified Vendor Sources and Current Gaps

- mise: the official Linux installer documents the single-binary `mise.run` path at `https://mise.jdx.dev/installing-mise.html`.
- Ollama: official Linux and GPU documentation is at `https://docs.ollama.com/linux` and `https://docs.ollama.com/gpu`; NVIDIA and AMD/ROCm handling must be tested against the actual host rather than inferred from Arch package names.
- LM Studio: official system requirements state that Linux is distributed as an AppImage and Ubuntu 20.04 or newer is required; source `https://lmstudio.ai/docs/app/system-requirements`.
- Voxtype: official installation documentation covers Debian/Ubuntu, AppImage, model setup, daemon setup, and GPU acceleration; source `https://voxtype.io/docs/`.
- T3 Code: official installation documentation provides an `npx` path and Linux AppImage releases; source `https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md`.
- ChatGPT Desktop: official Linux preview documentation provides Ubuntu/Debian `.deb` packages for x64 and ARM64; source `https://learn.chatgpt.com/docs/linux/linux-app`.
- Grok Bot: an authoritative Linux desktop package source was not confirmed during planning. The port must not install an unofficial Linux repack and must report this as a gap until a vendor-backed path is verified.

## Fidelity Contract

1. Do not rewrite source behavior into a generic AI dashboard.
2. Preserve command names, aliases, argument forwarding, exit behavior, JSON fields, refresh behavior, fallback behavior, and security limits.
3. Keep source-independent files byte-identical where no host translation is required.
4. Isolate every host translation in an adapter with a source-to-target mapping and a test.
5. Preserve the separate Omarchy Agents and Hermes Harness surfaces.
6. Record every unavailable vendor feature explicitly. A missing Ubuntu package or unofficial substitute is a parity gap, not a successful port.
7. Do not claim 1:1 completion until source-level, functional, UI, security, and installed-artifact parity gates pass.

## Task 1: Freeze the Source Contract

**Objective:** Create machine-readable source manifests and acceptance fixtures before editing implementation files.

**Files:**
- Create: `source-contract/omarchy-source.json`
- Create: `source-contract/hermes-harness-source.json`
- Create: `source-contract/ai-feature-matrix.md`
- Create: `tests/source-contract/test_source_contract.py`

**Work:**
- Record repository URL, fork URL, branch, pinned commit, license, and checkout path.
- Enumerate the exact AI paths from Omarchy `bin/`, `default/`, `install/user/`, `shell/plugins/agents/`, `manual/`, and `test/shell.d/`.
- Enumerate all 12 Hermes Harness files and their SHA-256 values.
- Record the public behavior of launchers, usage panel, crash capture, skills, theme sync, AI installation menu, and Voxtype.
- Record the documentation/source discrepancy without normalizing it.

**Verification:**

```bash
python3 -m pytest tests/source-contract/test_source_contract.py -q
```

Expected: all pinned commits, required source paths, and expected source hashes are present.

## Task 2: Create the Kubuntu Port Skeleton

**Objective:** Add an isolated port layout without modifying existing Omarchy runtime behavior.

**Files:**
- Create: `kubuntu/README.md`
- Create: `kubuntu/libexec/`
- Create: `kubuntu/bin/`
- Create: `kubuntu/plasma/`
- Create: `kubuntu/skills/`
- Create: `kubuntu/tests/`
- Create: `kubuntu/install/`

**Work:**
- Define the Kubuntu installation prefix as `~/.local/share/omarchy-kubuntu-ai`.
- Define the source checkout path through `OMARCHY_KUBUNTU_AI_ROOT`; never hard-code the contributor home directory.
- Preserve the source XDG namespaces for default-agent state and usage records unless a source contract requires a translation.
- Add a port manifest that identifies every installed file and its owner for rollback.

**Verification:**

```bash
git diff --check
python3 -m pytest kubuntu/tests -q
```

Expected: clean diff and a passing empty-port smoke test.

## Task 3: Port the Hermes Harness Core

**Objective:** Preserve the Hermes Harness status contract and hardened I/O behavior outside Quickshell.

**Files:**
- Create: `kubuntu/ai-core/hermes-status`
- Create: `kubuntu/ai-core/hermes-safe-io`
- Create: `kubuntu/tests/test_hermes_status.sh`
- Create: `kubuntu/tests/test_hermes_safe_io.py`
- Modify: `source-contract/hermes-harness-source.json`

**Work:**
- Start from the pinned `scripts/hermes-status` and `scripts/hermes-safe-io`.
- Preserve bounded reads, `O_NOFOLLOW`, regular-file checks, timeout handling, subprocess-group cleanup, JSON validation, field precedence, and stale-data fallback.
- Translate only the executable path and installation prefix.
- Preserve `hermes`, `hermes-gateway.service`, `HERMES_HOME`, `XDG_STATE_HOME`, and `hermes-node` semantics.
- Never read `.env`, auth state, OAuth data, tokens, or private keys.

**Verification:**

```bash
bash -n kubuntu/ai-core/hermes-status
python3 -m py_compile kubuntu/ai-core/hermes-safe-io
bash kubuntu/tests/test_hermes_status.sh
python3 -m pytest kubuntu/tests/test_hermes_safe_io.py -q
```

Expected: valid installed/missing/gateway/model/session/node states and refusal of symlink, oversized-file, malformed-input, timeout, and output-overflow fixtures.

## Task 4: Port the Agent Launcher and mise Wrappers

**Objective:** Preserve all source agent aliases and exact initial-prompt/permission behavior on Kubuntu.

**Files:**
- Create: `kubuntu/bin/omarchy-mise-install`
- Create: `kubuntu/bin/omarchy-default-agent`
- Create: `kubuntu/bin/omarchy-agent`
- Create: `kubuntu/bin/omarchy-agent-prompt`
- Create: `kubuntu/libexec/kubuntu-agent-terminal`
- Create: `kubuntu/tests/test_agent_launcher.sh`
- Create: `kubuntu/tests/test_mise_wrappers.sh`

**Work:**
- Preserve the source aliases and default-agent file location.
- Preserve every agent-specific command and argument exactly.
- Keep lazy installation through mise; install mise user-locally rather than through pacman/AUR.
- Use Konsole only in the Kubuntu adapter, preserving working directory and prompt forwarding.
- Implement collision checks so an existing unrelated command is never overwritten.
- Preserve `--inline`, `--pick`, missing-default, missing-command, and positional-prompt error behavior.

**Verification:**

```bash
bash kubuntu/tests/test_agent_launcher.sh
bash kubuntu/tests/test_mise_wrappers.sh
```

Expected: all source aliases and launch argument vectors match the pinned source fixtures.

## Task 5: Port AI Usage Collection

**Objective:** Preserve the Omarchy Agents usage schemas, collectors, filtering, refresh, and sync semantics.

**Files:**
- Create: `kubuntu/ai-core/omarchy-agent-usage-update`
- Create: `kubuntu/ai-core/omarchy-agent-usage-claude`
- Create: `kubuntu/ai-core/omarchy-agent-usage-codex`
- Create: `kubuntu/ai-core/omarchy-agent-usage-fireworks`
- Create: `kubuntu/tests/test_usage_update.sh`
- Create: `kubuntu/tests/test_usage_collectors.sh`
- Create: `kubuntu/tests/fixtures/usage/`

**Work:**
- Start from the pinned collectors and preserve their provider-specific parsing and output schema.
- Preserve `--force`, `--limits-only`, `--except`, named collector selection, atomic record writes, and failure aggregation.
- Keep credentials out of display data and fixtures.
- Preserve local-versus-synced usage distinctions and account-global limit semantics.
- Translate only paths, command discovery, and the user-level scheduler integration.

**Verification:**

```bash
bash kubuntu/tests/test_usage_update.sh
bash kubuntu/tests/test_usage_collectors.sh
```

Expected: good records are written atomically, invalid records are rejected, excluded collectors are skipped, and offline/retry states match source behavior.

## Task 6: Port Crash Capture and AI Diagnosis

**Objective:** Preserve evidence-first crash notifications, diagnosis handoff, mute behavior, and global toggle semantics.

**Files:**
- Create: `kubuntu/bin/omarchy-agent-crash`
- Create: `kubuntu/bin/omarchy-crash-watch`
- Create: `kubuntu/bin/omarchy-crash-mute`
- Create: `kubuntu/bin/omarchy-toggle-crash-capture`
- Create: `kubuntu/libexec/kubuntu-notify-crash`
- Create: `kubuntu/systemd/user/omarchy-crash-watch.service`
- Create: `kubuntu/tests/test_crash_capture.sh`
- Copy: `default/agents/skills/diagnose-crash/*` to `kubuntu/skills/diagnose-crash/`

**Work:**
- Preserve systemd-coredump/journal filtering, per-program mute paths, deduplication, and diagnosis arguments.
- Use KDE notification actions through the user session bus; verify the clicked diagnosis action launches the exact default-agent route.
- Use a fresh temporary core path and delete it after diagnosis.
- Preserve the no-auto-fix and no-auto-report boundaries.
- Install only a user service; do not create a system service.

**Verification:**

```bash
bash kubuntu/tests/test_crash_capture.sh
systemd-analyze --user verify kubuntu/systemd/user/omarchy-crash-watch.service
```

Expected: unmuted crashes notify, muted crashes do not, later crashes remain visible, diagnosis receives the correct path/name, and the watcher survives ignored entries.

## Task 7: Port Omarchy Skills and Theme Sync

**Objective:** Preserve skill discovery and agent-facing theme synchronization without importing Hyprland-only mutations.

**Files:**
- Create: `kubuntu/skills/omarchy/`
- Create: `kubuntu/bin/omarchy-theme-set-claude`
- Create: `kubuntu/bin/omarchy-theme-set-pi`
- Create: `kubuntu/bin/omarchy-theme-set-opencode`
- Create: `kubuntu/bin/omarchy-theme-refresh`
- Create: `kubuntu/tests/test_skills_and_theme_sync.sh`

**Work:**
- Copy source-independent skill content exactly, then document the Kubuntu host boundary where the source skill names Hyprland or Omarchy paths.
- Preserve symlink targets for all supported agent skill directories.
- Preserve atomic theme file replacement and activation semantics.
- Add a Plasma/Kubuntu theme source adapter; do not claim full desktop theme parity unless it is verified.

**Verification:**

```bash
bash kubuntu/tests/test_skills_and_theme_sync.sh
```

Expected: all supported agent skill paths resolve to the installed port skill, and theme sync is atomic and rollback-safe.

## Task 8: Port AI Install/Remove Adapters

**Objective:** Reproduce the pinned `Install > AI` surface using source-backed Kubuntu installation methods.

**Files:**
- Create: `kubuntu/bin/omarchy-install-ai-chatgpt`
- Create: `kubuntu/bin/omarchy-install-ai-grok-bot`
- Create: `kubuntu/bin/omarchy-install-ai-lm-studio`
- Create: `kubuntu/bin/omarchy-install-ai-ollama`
- Create: `kubuntu/bin/omarchy-install-ai-t3-code`
- Create: `kubuntu/bin/omarchy-voxtype-install`
- Create: `kubuntu/bin/omarchy-remove-ai-*`
- Create: `kubuntu/bin/omarchy-voxtype-remove`
- Create: `kubuntu/libexec/kubuntu-package-backend`
- Create: `kubuntu/docs/vendor-install-matrix.md`
- Create: `kubuntu/tests/test_ai_installers.sh`

**Work:**
- Map the exact source package identities to authoritative Ubuntu/vendor installation sources.
- Prefer apt, Flatpak, official `.deb`, AppImage, or vendor installer only when the source is documented and verifiable.
- Keep installer actions explicit and user-local where possible.
- Preserve removal boundaries, especially Codex CLI state versus ChatGPT desktop state, LM Studio relocation pointers, Grok CLI state, and T3 Code’s bootstrapped agent state.
- Keep Voxtype model/config/status behavior and source hotkeys, mapping Hyprland bindings to KDE global shortcuts.
- If a vendor provides no authoritative Linux artifact, leave the feature visible as unavailable with a precise reason and do not substitute another application.

**Verification:**

```bash
bash kubuntu/tests/test_ai_installers.sh
```

Expected: dry-run and fixture tests prove package selection, refusal of unknown sources, cleanup boundaries, and rollback behavior without deleting real user data.

## Task 9: Implement Plasma 6 Widgets

**Objective:** Port both visible source surfaces to Plasma 6 while preserving labels, states, controls, refresh, and keyboard behavior.

**Files:**
- Create: `kubuntu/plasma/omarchy-agents/package/metadata.json`
- Create: `kubuntu/plasma/omarchy-agents/package/contents/ui/main.qml`
- Create: `kubuntu/plasma/omarchy-agents/package/contents/ui/AgentsPanel.qml`
- Create: `kubuntu/plasma/omarchy-agents/package/contents/config/main.xml`
- Create: `kubuntu/plasma/omarchy-agents/package/contents/config/config.qml`
- Create: `kubuntu/plasma/hermes-harness/package/metadata.json`
- Create: `kubuntu/plasma/hermes-harness/package/contents/ui/main.qml`
- Create: `kubuntu/plasma/hermes-harness/package/contents/ui/HermesPanel.qml`
- Create: `kubuntu/plasma/hermes-harness/package/contents/config/main.xml`
- Create: `kubuntu/plasma/hermes-harness/package/contents/config/config.qml`
- Create: `kubuntu/tests/test_plasma_packages.sh`

**Work:**
- Use Plasma 6 `PlasmoidItem`, compact representation, full representation, and JSON metadata.
- Preserve Hermes Harness glyph states, six status facts, refresh interval, click mapping, and Open Hermes action.
- Preserve Omarchy Agents provider selection, usage sections, limit/balance displays, synced-provider behavior, refresh actions, and keyboard navigation.
- Preserve plain-text rendering for dynamic telemetry.
- Do not merge the two widgets.

**Verification:**

```bash
bash kubuntu/tests/test_plasma_packages.sh
kpackagetool6 --type Plasma/Applet --install kubuntu/plasma/omarchy-agents/package
kpackagetool6 --type Plasma/Applet --install kubuntu/plasma/hermes-harness/package
```

Expected: both packages validate and install without QML import errors.

## Task 10: Add Kubuntu Session Integration

**Objective:** Wire the port into KDE without modifying Plasma system files.

**Files:**
- Create: `kubuntu/systemd/user/omarchy-agent-usage-update.service`
- Create: `kubuntu/systemd/user/omarchy-agent-usage-update.timer`
- Create: `kubuntu/install/kubuntu-install.sh`
- Create: `kubuntu/install/kubuntu-uninstall.sh`
- Create: `kubuntu/install/kubuntu-global-shortcut.desktop`
- Create: `kubuntu/tests/test_install_rollback.sh`

**Work:**
- Install user files under `~/.local/share`, `~/.local/bin`, `~/.local/share/plasma/plasmoids`, and `~/.config/systemd/user`.
- Register `Super + Shift + Ctrl + A` for `omarchy-agent --pick` through KDE’s user-level shortcut path.
- Install the usage update timer at the source’s 15-minute cadence.
- Add `--dry-run`, collision checks, ownership checks, and an uninstall manifest.
- Never overwrite unrelated existing commands or config.
- Never write to `/usr`, `/etc`, `/usr/share/omarchy`, or another profile.

**Verification:**

```bash
bash kubuntu/tests/test_install_rollback.sh
./kubuntu/install/kubuntu-install.sh --dry-run
```

Expected: dry-run lists every write target and collision, and the rollback fixture removes only files owned by the port.

## Task 11: Full Parity and Visual Review

**Objective:** Prove the port against the pinned source and the real Kubuntu session.

**Files:**
- Create: `docs/parity-report.md`
- Create: `docs/kubuntu-install.md`
- Create: `tests/run-parity.sh`

**Verification:**

```bash
./tests/run-parity.sh
bash -n kubuntu/bin/* kubuntu/libexec/*
python3 -m pytest kubuntu/tests -q
./kubuntu/install/kubuntu-install.sh --dry-run
```

Then, in the live Plasma session:

- install both plasmoids;
- inspect compact and expanded states;
- exercise left, middle, and right click paths;
- exercise keyboard navigation and global shortcut launch;
- verify no-data, stale-data, malformed-data, unavailable-node, and gateway states;
- verify the crash notification action and mute toggle;
- verify usage refresh at the configured cadence;
- capture screenshots for each visually distinct state;
- inspect Plasma and user-service logs for errors;
- compare the installed files against the checkout manifest.

The final report must separate proven behavior, host mappings, unavailable vendor features, warnings, and blockers. A passing process or timeout is not a parity pass.

## Task 12: Commit, Push, and Release Only After Verification

**Objective:** Publish the verified port without polluting the upstream branch or claiming unverified fidelity.

**Work:**
- Keep commits atomic by feature slice.
- Run `git diff --check`, the full focused test suite, and installed-artifact comparison.
- Push only the `kubuntu-ai-port` branch to the user fork.
- Create release documentation only after the parity report has no unresolved blocking gaps.
- Preserve upstream remotes and pinned source metadata.

**Expected final state:** a reproducible Kubuntu install with source-backed parity evidence, explicit host mappings, rollback support, and no hidden privilege or credential behavior.
