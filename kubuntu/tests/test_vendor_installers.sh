#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
backend="$repo_root/kubuntu/libexec/kubuntu-vendor-install"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"
mkdir -p "$HOME"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$backend" ]] || fail "vendor backend is missing"

output=$("$backend" --dry-run install-deb \
  https://learn.chatgpt.com/download/chatgpt_amd64.deb \
  0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef)
grep -Fq 'dry-run' <<<"$output" || fail "deb dry-run did not report dry-run"
grep -Fq 'chatgpt_amd64.deb' <<<"$output" || fail "deb dry-run omitted artifact"
[[ ! -e "$HOME/.local/share/omarchy-kubuntu-ai" ]] || fail "deb dry-run wrote files"

output=$("$backend" --dry-run install-appimage lmstudio \
  https://lmstudio.ai/download/latest/linux/x64 \
  '')
grep -Fq 'dry-run' <<<"$output" || fail "AppImage dry-run did not report dry-run"

action_status=0
"$backend" --dry-run install-deb https://example.com/not-official.deb '' >/dev/null 2>&1 || action_status=$?
(( action_status != 0 )) || fail "untrusted vendor URL was accepted"

output=$("$backend" --dry-run gap grok-bot)
grep -Fq 'unsupported' <<<"$output" || fail "unsupported feature was not reported explicitly"

printf 'ok - vendor backend enforces official sources and dry-run isolation\n'
