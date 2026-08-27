#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
watcher="$repo_root/kubuntu/bin/omarchy-crash-watch"
muter="$repo_root/kubuntu/bin/omarchy-crash-mute"
diagnose="$repo_root/kubuntu/bin/omarchy-agent-crash"
unit="$repo_root/kubuntu/systemd/user/omarchy-crash-watch.service"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
test_home="$tmp_dir/home"
journal_file="$tmp_dir/journal.json"
notify_log="$tmp_dir/notify.log"
agent_log="$tmp_dir/agent.log"
mkdir -p "$fake_bin" "$test_home"
: >"$journal_file"
: >"$notify_log"
: >"$agent_log"

cat >"$fake_bin/journalctl" <<'SCRIPT'
#!/bin/bash
cat "$JOURNAL_FILE"
SCRIPT
cat >"$fake_bin/omarchy-default-agent" <<'SCRIPT'
#!/bin/bash
printf 'claude\n'
SCRIPT
cat >"$fake_bin/omarchy-notification-wait" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
cat >"$fake_bin/omarchy-notification-send" <<'SCRIPT'
#!/bin/bash
printf 'arg=%q\n' "$@" >>"$NOTIFY_LOG"
SCRIPT
cat >"$fake_bin/omarchy-agent-crash" <<'SCRIPT'
#!/bin/bash
printf 'arg=%q\n' "$@" >>"$AGENT_CRASH_LOG"
SCRIPT
cat >"$fake_bin/omarchy-agent" <<'SCRIPT'
#!/bin/bash
printf 'arg=%q\n' "$@" >>"$AGENT_CRASH_LOG"
SCRIPT
cat >"$fake_bin/coredumpctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' '2026-08-27 21:00:00'
SCRIPT
chmod +x "$fake_bin"/*

export HOME="$test_home"
export PATH="$fake_bin:$repo_root/kubuntu/bin:/usr/bin:/bin"
export JOURNAL_FILE="$journal_file"
export NOTIFY_LOG="$notify_log"
export AGENT_CRASH_LOG="$agent_log"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

bash -n "$watcher" "$muter" "$diagnose"

jq -cn --arg uid "$UID" '{_UID:$uid,COREDUMP_COMM:"chrome",COREDUMP_PID:"42",COREDUMP_EXE:"/usr/bin/chromium-browser",COREDUMP_SIGNAL_NAME:"SIGSEGV"}' >"$journal_file"
"$watcher"
expected_title=$(printf '%q' 'Process crashed: chromium-browser')
grep -Fxq "arg=$expected_title" "$notify_log" || fail "current-user crash was not announced by executable basename"
grep -Fq 'arg=42' "$notify_log" || fail "diagnosis PID was not forwarded"
grep -Fq 'arg=/usr/bin/chromium-browser' "$notify_log" || fail "diagnosis executable was not forwarded"

: >"$notify_log"
jq -cn '{_UID:"999999",COREDUMP_COMM:"other",COREDUMP_PID:"99",COREDUMP_EXE:"/usr/bin/other",COREDUMP_SIGNAL_NAME:"SIGABRT"}' >"$journal_file"
"$watcher"
[[ ! -s "$notify_log" ]] || fail "another user crash was announced"

: >"$notify_log"
"$muter" chromium-browser on
"$watcher"
[[ ! -s "$notify_log" ]] || fail "muted crash was announced"
"$muter" chromium-browser off

: >"$agent_log"
"$diagnose" 42 chrome /usr/bin/chrome SIGSEGV
 grep -Fq 'arg=--prompt' "$agent_log" || fail "diagnosis did not launch the default agent"
grep -Fq 'kubuntu/skills/diagnose-crash/SKILL.md' "$agent_log" || fail "diagnosis used the wrong skill path"

grep -Fxq 'ExecStart=/usr/bin/env omarchy-crash-watch' "$unit" || fail "user unit does not use a stable executable"
grep -Fxq 'Environment="PATH=%h/.local/share/omarchy-kubuntu-ai/bin:%h/.local/bin:/usr/bin:/bin"' "$unit" || fail "user unit does not define the port PATH"

printf 'ok - crash watcher, mute, diagnosis, and user unit are portable\n'
