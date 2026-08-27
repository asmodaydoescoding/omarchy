# Kubuntu AI Vendor Installation Matrix

This matrix records the source-backed Kubuntu mappings for Omarchy's `Install > AI` entries. The source package names are Arch/Omarchy identifiers and are not treated as Ubuntu package names.

| Source feature | Official Kubuntu source | Install form | State |
|---|---|---|---|
| ChatGPT Desktop | `https://learn.chatgpt.com/docs/linux/linux-app` | Official Ubuntu/Debian `.deb`, x64 or ARM64 | Supported with explicit package URL/checksum confirmation |
| LM Studio | `https://lmstudio.ai/docs/app/system-requirements` | Official Linux AppImage, x64 or ARM64 | Supported with explicit download URL/checksum confirmation |
| Ollama | `https://docs.ollama.com/linux` and `https://docs.ollama.com/gpu` | Official Linux installer or archive; optional NVIDIA/AMD ROCm layer | Supported, GPU path is host-dependent and never inferred from Arch package names |
| T3 Code | `https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md` | Official Linux AppImage or documented `npx` path | Supported with explicit release URL/checksum confirmation |
| Voxtype | `https://voxtype.io/docs/` | Official Ubuntu `.deb` or AppImage plus model setup | Supported on Ubuntu 24.04+/glibc 2.39+; source build fallback required for older hosts |
| Grok Bot | xAI desktop documentation does not expose a verified Linux package in the current source audit | None | Explicit gap; unofficial repacks are prohibited |

## Installer rules

- All installers support `--dry-run` and produce no writes in that mode.
- A real download requires an explicit official URL. A mutable “latest” URL is not silently trusted for a release artifact.
- When a checksum is available from the vendor, the installer verifies it before installation.
- `.deb` installation requires an interactive sudo prompt and uses `apt` for dependency resolution.
- AppImages stay under the user-local port prefix and never write to `/usr`.
- Ollama's system service and GPU driver installation are separate opt-in operations.
- Grok Bot remains listed as unavailable until an authoritative Linux artifact exists.
