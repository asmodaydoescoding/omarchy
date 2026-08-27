#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
notify="$repo_root/kubuntu/bin/omarchy-notification-send"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
notify_log="$tmp_dir/notify.log"
exec_log="$tmp_dir/exec.log"
mkdir -p "$fake_bin"

cat >"$fake_bin/notify-send" <<'SCRIPT'
#!/bin/bash
printf 'arg=%q\n' "$@" >>"$NOTIFY_LOG"
if [[ ${NOTIFY_ACTION:-none} == "diagnose" ]]; then
  printf 'diagnose\n'
fi
SCRIPT
cat >"$fake_bin/test-action" <<'SCRIPT'
#!/bin/bash
printf 'action' >>"$EXEC_LOG"
printf ' arg=%q' "$@" >>"$EXEC_LOG"
printf '\n' >>"$EXEC_LOG"
SCRIPT
chmod +x "$fake_bin"/*

export PATH="$fake_bin:/usr/bin:/bin"
export NOTIFY_LOG="$notify_log"
export EXEC_LOG="$exec_log"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$notify" ]] || fail "notification adapter is missing"

NOTIFY_ACTION=diagnose "$notify" --app-name omarchy-action -u critical -g glyph \
  'Process crashed: hostile;name' 'Click to diagnose' --exec test-action 'arg with spaces' 'value=$HOME'

grep -Fxq 'arg=--urgency' "$notify_log" || fail "urgency was not forwarded"
grep -Fxq 'arg=critical' "$notify_log" || fail "critical urgency was not preserved"
grep -Fxq 'arg=--wait' "$notify_log" || fail "action notifications did not wait for selection"
expected_headline=$(printf '%q' 'Process crashed: hostile;name')
expected_description=$(printf '%q' 'Click to diagnose')
expected_spaced=$(printf '%q' 'arg with spaces')
expected_shell=$(printf '%q' 'value=$HOME')
grep -Fxq "arg=$expected_headline" "$notify_log" || fail "headline was not preserved"
grep -Fxq "arg=$expected_description" "$notify_log" || fail "description was not preserved"
expected_action=$(printf '%q' '--action=diagnose=Diagnose with AI')
grep -Fxq "arg=$expected_action" "$notify_log" || fail "diagnosis action was not exposed"
grep -Fq "action arg=$expected_spaced" "$exec_log" || fail "exec argv lost spaces"
grep -Fq "arg=$expected_shell" "$exec_log" || fail "exec argv was reparsed"

: >"$notify_log"
NOTIFY_ACTION=none "$notify" 'Plain notification' 'Body'
! grep -Fq -- '--wait' "$notify_log" || fail "plain notifications unexpectedly waited"

printf 'ok - KDE notifications preserve text, actions, and exec argv\n'
