#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
waiter="$repo_root/kubuntu/bin/omarchy-notification-wait"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
log_file="$tmp_dir/busctl.log"
mkdir -p "$fake_bin"
: >"$log_file"
cat >"$fake_bin/busctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$BUSCTL_LOG"
[[ ${NOTIFICATION_SERVER_MODE:-ready} == "ready" ]]
SCRIPT
chmod +x "$fake_bin/busctl"

export PATH="$fake_bin:/usr/bin:/bin"
export BUSCTL_LOG="$log_file"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$waiter" ]] || fail "notification waiter is missing"
NOTIFICATION_SERVER_MODE=ready "$waiter" 1
[[ -s "$log_file" ]] || fail "waiter did not query the notification server"

: >"$log_file"
if NOTIFICATION_SERVER_MODE=missing "$waiter" 0; then
  fail "waiter accepted an unavailable notification server"
fi

printf 'ok - notification waiter uses bounded user-bus readiness checks\n'
