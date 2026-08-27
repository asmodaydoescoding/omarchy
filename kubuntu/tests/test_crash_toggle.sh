#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
toggle="$repo_root/kubuntu/bin/omarchy-toggle"
enabled="$repo_root/kubuntu/bin/omarchy-toggle-enabled"
crash_toggle="$repo_root/kubuntu/bin/omarchy-toggle-crash-capture"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
test_home="$tmp_dir/home"
system_log="$tmp_dir/system.log"
notify_log="$tmp_dir/notify.log"
mkdir -p "$fake_bin" "$test_home"
: >"$system_log"
: >"$notify_log"

cat >"$fake_bin/systemctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$SYSTEM_LOG"
SCRIPT
cat >"$fake_bin/omarchy-notification-send" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
SCRIPT
chmod +x "$fake_bin"/*

export HOME="$test_home"
export SYSTEM_LOG="$system_log"
export NOTIFY_LOG="$notify_log"
export PATH="$fake_bin:$repo_root/kubuntu/bin:/usr/bin:/bin"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

bash -n "$toggle" "$enabled" "$crash_toggle"

"$toggle" crash-capture-off on
"$enabled" crash-capture-off || fail "enabled did not see the on flag"
[[ -f "$HOME/.local/state/omarchy/toggles/crash-capture-off" ]] || fail "on did not create the flag"

"$toggle" crash-capture-off off
"$enabled" crash-capture-off && fail "enabled saw a removed flag"
[[ ! -e "$HOME/.local/state/omarchy/toggles/crash-capture-off" ]] || fail "off did not remove the flag"

: >"$system_log"
: >"$notify_log"
"$crash_toggle"
grep -Fxq -- '--user stop omarchy-crash-watch.service' "$system_log" || fail "disable did not stop the watcher"
grep -Fq 'Crash capture disabled' "$notify_log" || fail "disable did not notify"

: >"$system_log"
: >"$notify_log"
"$crash_toggle"
grep -Fxq -- '--user start omarchy-crash-watch.service' "$system_log" || fail "enable did not start the watcher"
grep -Fq 'Crash capture enabled' "$notify_log" || fail "enable did not notify"

for bad in ../escape /absolute ./dot crash-ignore/../escape; do
  if "$toggle" "$bad" on >/dev/null 2>&1; then
    fail "toggle accepted unsafe name $bad"
  fi
  if "$enabled" "$bad" >/dev/null 2>&1; then
    fail "enabled accepted unsafe name $bad"
  fi
done
[[ ! -e "$HOME/.local/state/omarchy/escape" ]] || fail "unsafe toggle escaped its state directory"

printf 'ok - crash toggles preserve state transitions and reject traversal\n'
