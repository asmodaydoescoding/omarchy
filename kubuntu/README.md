# Kubuntu Omarchy AI Port

This directory contains the Kubuntu/Plasma 6 adapter for the pinned Omarchy AI feature layer and the pinned Hermes Harness source. It is not a full Omarchy distribution fork and does not replace Kubuntu's desktop, Plasma shell, package database, or system configuration.

The source-independent AI behavior remains contract-compatible with the pinned sources. Host-facing behavior is isolated under `kubuntu/` and is translated only where Kubuntu lacks an Arch, Hyprland, Omarchy shell, or Quickshell primitive.

## Source boundary

The source checkouts are recorded in `../source-contract/` and remain read-only reference inputs for the port. The active source baseline is Omarchy `quattro` commit `946704f30950576731d91a732b743f7c7fa8b188` and Hermes Harness `main` commit `2d7268800ee36eb36ba837c9755ebb3536f73d62`.

Set `OMARCHY_KUBUNTU_AI_ROOT` when invoking the port from another checkout. The installation prefix is user-local: `~/.local/share/omarchy-kubuntu-ai`.

The port preserves the source XDG namespaces for default-agent state, usage records, Hermes configuration, crash mutes, skills, and agent-facing theme files unless a documented host adapter requires a separate path.

## Safety boundary

The installer writes only to user-local paths, Plasma's user plasmoid directory, and the user's systemd configuration. It does not write to `/usr`, `/etc`, `/usr/share/omarchy`, package-managed Omarchy files, or another Hermes profile. It does not read, copy, or print `.env` files, API keys, OAuth state, auth stores, SSH private keys, or other credentials.

The port manifest records every file and link owned by the installer so uninstall can remove only port-owned state. Existing commands and configuration are never overwritten without an ownership match.

## Layout

- `ai-core/` — source-compatible AI scripts and data contracts.
- `bin/` — user-facing port command entry points.
- `libexec/` — Kubuntu host adapters for packages, Konsole, notifications, and session integration.
- `plasma/` — Plasma 6 widget packages for Omarchy Agents and Hermes Harness.
- `skills/` — source-compatible agent skills.
- `install/` — user-local install and rollback entry points.
- `tests/` — port-specific fixtures and parity tests.
- `port-manifest.json` — deterministic ownership and source metadata for installation and rollback.

No directory is considered implemented merely because its marker exists. Each later feature slice must add its own tests and verified runtime behavior before it is marked complete.
