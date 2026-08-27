#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
router="$repo_root/kubuntu/bin/omarchy"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
fake_bin="$tmp_dir/bin"
log_file="$tmp_dir/log"
mkdir -p "$fake_bin"
: >"$log_file"

for name in omarchy-agent omarchy-agent-prompt omarchy-default-agent omarchy-agent-usage-update omarchy-agent-crash omarchy-crash-mute omarchy-toggle-crash-capture omarchy-notification-send omarchy-voxtype-install omarchy-voxtype-remove omarchy-install-ai-chatgpt omarchy-remove-ai-chatgpt omarchy-theme-refresh; do
  cat >"$fake_bin/$name" <<'SCRIPT'
#!/bin/bash
printf '%s' "${0##*/}" >>"$ROUTER_LOG"
printf ' arg=%q' "$@" >>"$ROUTER_LOG"
printf '\n' >>"$ROUTER_LOG"
SCRIPT
  chmod +x "$fake_bin/$name"
done

export PATH="$fake_bin:/usr/bin:/bin"
export ROUTER_LOG="$log_file"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$router" ]] || fail "omarchy router is missing"

assert_last() {
  local expected=$1 actual
  actual=$(python3 - "$log_file" <<'PY'
from pathlib import Path
import sys
lines=Path(sys.argv[1]).read_text().splitlines()
print(lines[-1] if lines else '')
PY
)
  [[ "$actual" == "$expected" ]] || fail "expected [$expected], got [$actual]"
}

"$router" agent
assert_last "omarchy-agent arg=''"
"$router" agent prompt 'Review this project'
assert_last 'omarchy-agent-prompt arg=Review\ this\ project'
"$router" default agent codex
assert_last 'omarchy-default-agent arg=codex'
"$router" agent usage-update --force
assert_last 'omarchy-agent-usage-update arg=--force'
"$router" agent crash 42
assert_last 'omarchy-agent-crash arg=42'
"$router" crash mute chromium-browser off
assert_last 'omarchy-crash-mute arg=chromium-browser arg=off'
"$router" toggle crash-capture
assert_last "omarchy-toggle-crash-capture arg=''"
"$router" notification send Title Body
assert_last 'omarchy-notification-send arg=Title arg=Body'
"$router" install ai chatgpt --dry-run
assert_last 'omarchy-install-ai-chatgpt arg=--dry-run'
"$router" remove ai chatgpt --dry-run
assert_last 'omarchy-remove-ai-chatgpt arg=--dry-run'
"$router" voxtype install --dry-run
assert_last 'omarchy-voxtype-install arg=--dry-run'
"$router" theme refresh
assert_last "omarchy-theme-refresh arg=''"

if "$router" unsupported >/dev/null 2>&1; then
  fail "unsupported router command succeeded"
fi

printf 'ok - omarchy AI command routes preserve source command forms\n'
