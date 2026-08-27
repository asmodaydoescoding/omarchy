# Omarchy AI Source Feature Matrix

Pinned Omarchy source commit: `946704f30950576731d91a732b743f7c7fa8b188` (`quattro`).
Pinned Hermes Harness source commit: `2d7268800ee36eb36ba837c9755ebb3536f73d62` (`main`).

## agent_launch

**Source paths:** bin/omarchy, bin/omarchy-agent, bin/omarchy-agent-prompt, bin/omarchy-default-agent, bin/omarchy-mise-install, bin/omarchy-launch-tui, bin/omarchy-launch-floating-terminal-with-presentation, install/user/mise.sh, install/user/mise-work.sh, install/user/first-run/setup-agent.hook, default/omarchy/omarchy-menu.jsonc, default/bash/aliases, default/hypr/qconsole.lua, test/shell.d/default-agent-test.sh, test/shell.d/agent-invitation-test.sh

**Observable behavior:** lazy mise wrappers; persisted default agent; exact aliases, prompt routing, inline/pick behavior, and source-specific unattended flags.

**Kubuntu seam:** Kubuntu replaces only mise bootstrap, terminal window launch, global shortcut, and package backend; command vectors and XDG state remain source-compatible.

**Parity test:** `test_agent_launcher.sh and test_mise_wrappers.sh`

## agent_usage

**Source paths:** bin/omarchy-agent-usage-claude, bin/omarchy-agent-usage-codex, bin/omarchy-agent-usage-fireworks, bin/omarchy-agent-usage-update, shell/plugins/agents/Agent.qml, shell/plugins/agents/Main.qml, shell/plugins/agents/Panel.qml, shell/plugins/agents/README.md, shell/plugins/agents/manifest.json, shell/plugins/agents/assets/claude.svg, shell/plugins/agents/assets/codex.svg, shell/plugins/agents/assets/codex-light.svg, shell/plugins/agents/assets/fireworks.svg, test/shell.d/agent-usage-claude-limits-test.sh, test/shell.d/agent-usage-claude-scanner-test.sh, test/shell.d/agent-usage-codex-scanner-test.sh, test/shell.d/agent-usage-fireworks-scanner-test.sh, test/shell.d/agent-usage-update-test.sh, test/shell.d/agents-panel-test.sh, test/shell.d/agents-default-migration-test.sh, test/shell.d/agents-rename-migration-test.sh

**Observable behavior:** Claude, Codex, Fireworks collectors; one JSON record per collector; limits, balance, token charts, atomic writes, refresh filtering, and synced device aggregation.

**Kubuntu seam:** Kubuntu keeps collector schemas and paths; only scheduler, command discovery, and Plasma rendering are adapted.

**Parity test:** `test_usage_update.sh and test_usage_collectors.sh`

## crash_diagnosis

**Source paths:** bin/omarchy-agent-crash, bin/omarchy-crash-watch, bin/omarchy-crash-mute, bin/omarchy-toggle-crash-capture, bin/omarchy-notification-send, bin/omarchy-notification-wait, bin/omarchy-toggle, bin/omarchy-toggle-enabled, default/systemd/user/omarchy-crash-watch.service, default/agents/skills/diagnose-crash/SKILL.md, default/agents/skills/diagnose-crash/reporting.md, test/shell.d/crash-capture-test.sh

**Observable behavior:** systemd-coredump journal watch; current-user filtering; dedupe; critical notification to the default agent; per-program mute; global toggle; diagnose-crash skill; no automatic fix/report.

**Kubuntu seam:** Kubuntu uses the existing user systemd manager, coredumpctl/journalctl, and KDE notification actions instead of Omarchy shell notification IPC.

**Parity test:** `test_crash_capture.sh`

## skills_theme

**Source paths:** default/agents/skills/omarchy/SKILL.md, default/agents/skills/omarchy/capture.md, default/agents/skills/omarchy/contributing.md, default/agents/skills/omarchy/hooks.md, default/agents/skills/omarchy/hyprland.md, default/agents/skills/omarchy/plugins.md, default/agents/skills/omarchy/theming.md, bin/omarchy-theme-set, bin/omarchy-theme-refresh, bin/omarchy-theme-set-claude, bin/omarchy-theme-set-pi, default/themed/claude.json.tpl, default/themed/pi.json.tpl, config/opencode/opencode.json, test/shell.d/theme-staging-test.sh, test/shell.d/vscode-theme-test.sh

**Observable behavior:** Omarchy and diagnose-crash skills; agent skill links; generated Claude/Pi/OpenCode themes; atomic updates.

**Kubuntu seam:** Kubuntu preserves skill target paths and generated files, adapting only the Plasma/Kubuntu theme source and event hook.

**Parity test:** `test_skills_and_theme_sync.sh`

## ai_install_menu

**Source paths:** bin/omarchy-install-ai-chatgpt, bin/omarchy-remove-ai-chatgpt, bin/omarchy-remove-ai-grok-bot, bin/omarchy-remove-ai-lm-studio, bin/omarchy-remove-ai-ollama, bin/omarchy-remove-ai-t3-code, default/omarchy/omarchy-menu.jsonc, test/shell.d/remove-ai-test.sh

**Observable behavior:** ChatGPT Desktop, Dictation, Grok Bot, LM Studio, Ollama, T3 Code, with package-aware install/remove guards.

**Kubuntu seam:** Arch package names are mapped to official Ubuntu/vendor installers; unsupported vendor artifacts remain explicit gaps and never become unofficial substitutes.

**Parity test:** `test_ai_installers.sh`

## voxtype

**Source paths:** bin/omarchy-voxtype-config, bin/omarchy-voxtype-install, bin/omarchy-voxtype-model, bin/omarchy-voxtype-remove, bin/omarchy-voxtype-status, bin/omarchy-capture-text, default/hypr/bindings/voxtype.lua, default/voxtype/config.toml, install/user/first-run/install-voxtype.hook, shell/plugins/bar/indicators/Dictation.qml, shell/plugins/bar/widgets/Indicators.qml, shell/plugins/bar/widgets/Indicators.manifest.json, manual/11-text-extraction-dictation.md, test/shell.d/voxtype-invitation-test.sh

**Observable behavior:** offline Whisper dictation; F9 push-to-talk; Super+Ctrl+X toggle; Voxtype config/model/status; optional OCR text capture.

**Kubuntu seam:** KDE global shortcuts and KDE/Wayland typing backends replace Hyprland bindings while Voxtype paths/config remain compatible.

**Parity test:** `test_voxtype.sh`

## harness

**Source paths:** BarWidget.qml, LICENSE, Panel.qml, README.md, docs/architecture.md, docs/security.md, docs/telemetry.md, docs/troubleshooting.md, manifest.json, scripts/hermes-safe-io, scripts/hermes-status, skill/SKILL.md

**Observable behavior:** Hermes Harness status/launch plugin; left panel, middle refresh, right launch; installed/version/gatewayState/activeModel/currentSessionId/currentSessionTitle/hermesNodeAvailable/nodesOnline/nodesTotal/nodes; safe bounded reads and subprocess capture; no credentials.

**Kubuntu seam:** Kubuntu replaces Quickshell/Omarchy plugin injection with a Plasma 6 compact/full plasmoid while preserving telemetry, interaction, and security contracts.

**Parity test:** `test_hermes_status.sh and test_hermes_safe_io.py`

## source-documentation-drift

**Source paths:** `bin/omarchy-default-agent`, `default/omarchy/omarchy-menu.jsonc`, `manual/17-ai.md`

**Observable behavior:** The pinned executable source supports `agy` and `ori`; public manual text still uses `gemini` wording and omits `ori`. The port follows the pinned executable source and preserves this discrepancy as evidence.

**Kubuntu seam:** Preserve both source aliases and document the source/manual mismatch; do not silently rename or remove an agent.

**Parity test:** `test_source_contract.py::test_feature_matrix`
