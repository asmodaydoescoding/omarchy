#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
aggregator="$repo_root/kubuntu/bin/omarchy-agent-usage-list"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/home" "$tmp_dir/state/omarchy/agents/usage"
printf '%s\n' '{"id":"claude","name":"Claude","totalTokens":12}' >"$tmp_dir/state/omarchy/agents/usage/claude.json"
printf '%s\n' 'invalid' >"$tmp_dir/state/omarchy/agents/usage/bad.json"
python3 - "$tmp_dir/state/omarchy/agents/usage/oversized.json" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text('{"id":"oversized","blob":"' + ('x' * 262145) + '"}\n')
PY

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$aggregator" ]] || fail "usage aggregator is missing"
output=$(HOME="$tmp_dir/home" XDG_STATE_HOME="$tmp_dir/state" "$aggregator")
printf '%s\n' "$output" | jq -e 'length == 1 and .[0].id == "claude" and .[0].totalTokens == 12' >/dev/null || fail "aggregator did not filter records correctly"
printf 'ok - usage aggregator preserves valid bounded records only\n'
