#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
updater="$repo_root/kubuntu/bin/omarchy-agent-usage-update"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_root="$tmp_dir/fake-root"
test_home="$tmp_dir/home"
usage_dir="$test_home/.local/state/omarchy/agents/usage"
mkdir -p "$fake_root/bin" "$test_home"

cat >"$fake_root/bin/omarchy-agent-usage-good" <<'SCRIPT'
#!/bin/bash
printf '%s\n' '{"schemaVersion":1,"id":"good","name":"Good Agent","totalPrompts":3}'
SCRIPT
cat >"$fake_root/bin/omarchy-agent-usage-noisy" <<'SCRIPT'
#!/bin/bash
printf '%s\n' 'not-json'
SCRIPT
cat >"$fake_root/bin/omarchy-agent-usage-skipped" <<'SCRIPT'
#!/bin/bash
printf '%s\n' '{"schemaVersion":1,"id":"skipped"}'
SCRIPT
cat >"$fake_root/bin/omarchy-agent-usage-update" <<'SCRIPT'
#!/bin/bash
printf '%s\n' '{"id":"update"}'
SCRIPT
chmod +x "$fake_root/bin"/*

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$updater" ]] || fail "usage updater is missing"

status=0
HOME="$test_home" XDG_STATE_HOME="" OMARCHY_PATH="$fake_root" \
  "$updater" --except skipped >/dev/null 2>&1 || status=$?
(( status != 0 )) || fail "updater hid a failing collector"
[[ $(jq -r '.name' "$usage_dir/good.json") == "Good Agent" ]] || fail "updater did not write the valid collector record"
[[ ! -e "$usage_dir/noisy.json" ]] || fail "updater wrote invalid collector output"
[[ ! -e "$usage_dir/skipped.json" ]] || fail "updater ignored --except"
[[ ! -e "$usage_dir/update.json" ]] || fail "updater treated itself as a collector"

HOME="$test_home" XDG_STATE_HOME="" OMARCHY_PATH="$fake_root" \
  "$updater" skipped >/dev/null
[[ -e "$usage_dir/skipped.json" ]] || fail "named collector selection did not run"
[[ ! -e "$usage_dir/noisy.json" ]] || fail "named collector selection ran an unrequested collector"

for name in claude codex fireworks update; do
  cmp -s "$repo_root/kubuntu/bin/omarchy-agent-usage-$name" "$repo_root/bin/omarchy-agent-usage-$name" ||
    fail "Kubuntu usage script diverges from pinned source: $name"
done

printf 'ok - usage updater preserves filtering, validation, atomic records, and source parity\n'
