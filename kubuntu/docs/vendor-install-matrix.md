# Kubuntu AI Vendor Install Matrix

All vendor installers default to dry-run. `--apply` is required for downloads, package installation, or privileged system changes. URLs are restricted to official HTTPS origins and optional SHA-256 values are verified before installation.

| Surface | Kubuntu path | Source policy | Install boundary | Status |
| --- | --- | --- | --- | --- |
| ChatGPT Desktop | Official `.deb` through `apt` | `persistent.oaistatic.com` or `learn.chatgpt.com` | Downloaded file is passed to `sudo apt install` only with `--apply` | Available through guarded wrapper |
| LM Studio | User-local AppImage | `lmstudio.ai` | Stored under `~/.local/share/omarchy-kubuntu-ai/apps/` | Available through guarded wrapper |
| Ollama | Official installer script | `ollama.com/install.sh` | Script is syntax-checked, then run with `sudo` only with `--apply` | Available through guarded wrapper |
| T3 Code | User-local AppImage | Official `github.com/pingdotgg/t3code` release source; a direct AppImage asset URL must be supplied | Stored under the port's user-local apps directory | Wrapper present; default release-page URL still needs direct-asset verification |
| Grok Bot | None confirmed | No authoritative Linux artifact was verified | No install or unofficial repack is attempted | Explicit unavailable gap |
| Voxtype | User service/config/model paths | `voxtype.io` and distro packages | User config and KDE shortcut guidance; model install remains explicit | Implemented; live model install not claimed |

## Removal boundary

Removers default to dry-run and remove only the named surface's known user-local state. They do not delete unrelated agent configuration, credentials, OAuth state, or package-managed files.

## Evidence rule

A vendor is not considered available merely because a URL exists. The artifact must be official, the URL must resolve to the expected file type, and checksum verification should be supplied for reproducible application. Grok Bot remains visible as an explicit gap until that evidence exists.
