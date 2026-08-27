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
  script="$repo_root/kubuntu/bin/omarchy-remove-ai-$name"
  [[ -x "$script" ]] || fail "missing remover $name"
  output=$("$script" --dry-run)
  if [[ "$name" == "grok-bot" ]]; then
    grep -Fq 'unsupported:' <<<"$output" || fail "Grok remover did not report its gap"
  else
    grep -Fq 'dry-run:' <<<"$output" || fail "remover $name did not stay in dry-run"
  fi
  bash -n "$script"
done

output=$("$repo_root/kubuntu/bin/omarchy-remove-ai-chatgpt" --dry-run)
grep -Fq 'Codex' <<<"$output" || fail "ChatGPT removal omitted its config boundary"
output=$("$repo_root/kubuntu/bin/omarchy-remove-ai-t3-code" --dry-run)
grep -Fq 'preserve' <<<"$output" || fail "T3 removal omitted preserved agent state"
output=$("$repo_root/kubuntu/bin/omarchy-remove-ai-grok-bot" --dry-run)
grep -Fq 'unsupported: grok-bot' <<<"$output" || fail "Grok removal did not preserve explicit gap"

[[ ! -e "$HOME/.local/share/omarchy-kubuntu-ai" ]] || fail "removers wrote during dry-run"
printf 'ok - AI removers preserve dry-run isolation and cleanup boundaries\n'
