#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
export HOME="$tmp_dir/home"
mkdir -p "$HOME"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

for name in chatgpt lm-studio ollama t3-code grok-bot; do
  script="$repo_root/kubuntu/bin/omarchy-install-ai-$name"
  [[ -x "$script" ]] || fail "missing installer $name"
  bash -n "$script"
done

output=$(CHATGPT_DEB_URL=https://learn.chatgpt.com/download/test.deb \
  "$repo_root/kubuntu/bin/omarchy-install-ai-chatgpt" --dry-run)
grep -Fq 'official deb' <<<"$output" || fail "ChatGPT wrapper did not route to deb backend"

output=$(LM_STUDIO_APPIMAGE_URL=https://lmstudio.ai/download/test.AppImage \
  "$repo_root/kubuntu/bin/omarchy-install-ai-lm-studio" --dry-run)
grep -Fq 'official AppImage' <<<"$output" || fail "LM Studio wrapper did not route to AppImage backend"

output=$("$repo_root/kubuntu/bin/omarchy-install-ai-ollama" --dry-run)
grep -Fq 'https://ollama.com/install.sh' <<<"$output" || fail "Ollama wrapper did not expose official installer"

output=$(T3CODE_APPIMAGE_URL=https://github.com/pingdotgg/t3code/releases/download/v-test/T3Code.AppImage \
  "$repo_root/kubuntu/bin/omarchy-install-ai-t3-code" --dry-run)
grep -Fq 'official AppImage' <<<"$output" || fail "T3 Code wrapper did not route to AppImage backend"

output=$("$repo_root/kubuntu/bin/omarchy-install-ai-grok-bot" --dry-run)
grep -Fq 'unsupported: grok-bot' <<<"$output" || fail "Grok Bot gap was not explicit"

[[ ! -e "$HOME/.local/share/omarchy-kubuntu-ai" ]] || fail "dry-run wrote user-local state"
printf 'ok - AI installer wrappers route to guarded vendor backends\n'
