#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
claude_sync="$repo_root/kubuntu/bin/omarchy-theme-set-claude"
pi_sync="$repo_root/kubuntu/bin/omarchy-theme-set-pi"
opencode_sync="$repo_root/kubuntu/bin/omarchy-theme-set-opencode"
refresh="$repo_root/kubuntu/bin/omarchy-theme-refresh"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

test_home="$tmp_dir/home"
state_theme="$test_home/.local/state/omarchy/current/theme"
mkdir -p "$state_theme" "$test_home/.claude" "$test_home/.pi/agent" "$test_home/.config/opencode"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

for script in "$claude_sync" "$pi_sync" "$opencode_sync" "$refresh"; do
  [[ -x "$script" ]] || fail "missing executable theme bridge $(basename "$script")"
done

claude_source='{"name":"claude-v1"}'
pi_source='{"name":"pi-v1"}'
opencode_source='{"theme":"omarchy-v1","autoupdate":false}'
printf '%s\n' "$claude_source" >"$state_theme/claude.json"
printf '%s\n' "$pi_source" >"$state_theme/pi.json"
printf '%s\n' "$opencode_source" >"$state_theme/opencode.json"
printf '%s\n' '{"theme":"old","keep":true}' >"$test_home/.claude/settings.json"
printf '%s\n' '{"theme":"old","keep":true}' >"$test_home/.pi/agent/settings.json"
printf '%s\n' '{"theme":"old","keep":true}' >"$test_home/.config/opencode/opencode.json"

HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$claude_sync" --activate
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$pi_sync" --activate
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$opencode_sync"

cmp -s "$state_theme/claude.json" "$test_home/.claude/themes/omarchy.json" || fail "Claude theme was not synced exactly"
cmp -s "$state_theme/pi.json" "$test_home/.pi/agent/themes/omarchy-system.json" || fail "Pi theme was not synced exactly"
cmp -s "$state_theme/opencode.json" "$test_home/.config/opencode/opencode.json" || fail "OpenCode theme was not synced exactly"
jq -e '.theme == "custom:omarchy" and .keep == true' "$test_home/.claude/settings.json" >/dev/null || fail "Claude activation did not preserve settings"
jq -e '.theme == "omarchy-system" and .keep == true' "$test_home/.pi/agent/settings.json" >/dev/null || fail "Pi activation did not preserve settings"

for directory in "$test_home/.claude/themes" "$test_home/.pi/agent/themes" "$test_home/.config/opencode"; do
  compgen -G "$directory/*.XXXXXX" >/dev/null && fail "temporary theme file leaked in $directory" || true
done

printf '%s\n' '{"name":"claude-v2"}' >"$state_theme/claude.json"
printf '%s\n' '{"name":"pi-v2"}' >"$state_theme/pi.json"
printf '%s\n' '{"theme":"omarchy-v2","autoupdate":true}' >"$state_theme/opencode.json"
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$refresh"
grep -Fq 'claude-v2' "$test_home/.claude/themes/omarchy.json" || fail "refresh did not update Claude"
grep -Fq 'pi-v2' "$test_home/.pi/agent/themes/omarchy-system.json" || fail "refresh did not update Pi"
grep -Fq 'omarchy-v2' "$test_home/.config/opencode/opencode.json" || fail "refresh did not update OpenCode"

rm "$state_theme/claude.json" "$state_theme/pi.json" "$state_theme/opencode.json"
printf 'sentinel\n' >"$test_home/.claude/themes/omarchy.json"
printf 'sentinel\n' >"$test_home/.pi/agent/themes/omarchy-system.json"
printf 'sentinel\n' >"$test_home/.config/opencode/opencode.json"
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" "$refresh"
grep -Fxq 'sentinel' "$test_home/.claude/themes/omarchy.json" || fail "missing Claude source was not a no-op"
grep -Fxq 'sentinel' "$test_home/.pi/agent/themes/omarchy-system.json" || fail "missing Pi source was not a no-op"
grep -Fxq 'sentinel' "$test_home/.config/opencode/opencode.json" || fail "missing OpenCode source was not a no-op"

printf 'ok - skills and Claude, Pi, OpenCode theme bridges are atomic, activating, and refreshable\n'
