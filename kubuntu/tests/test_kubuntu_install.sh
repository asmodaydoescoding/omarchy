#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
installer="$repo_root/kubuntu/install/kubuntu-install.sh"
uninstaller="$repo_root/kubuntu/install/kubuntu-uninstall.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
test_home="$tmp_dir/home"
prefix="$tmp_dir/prefix"
log_file="$tmp_dir/system.log"
mkdir -p "$fake_bin" "$test_home"
: >"$log_file"
cat >"$fake_bin/systemctl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$SYSTEM_LOG"
exit 0
SCRIPT
chmod +x "$fake_bin/systemctl"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

export HOME="$test_home"
export XDG_DATA_HOME="$test_home/.local/share"
export SYSTEM_LOG="$log_file"
export PATH="$fake_bin:/usr/bin:/bin"
export KUBUNTU_INSTALL_PREFIX="$prefix"

bash -n "$installer" "$uninstaller"

output=$("$installer" --dry-run)
grep -Fq 'dry-run:' <<<"$output" || fail "installer dry-run did not report"
[[ ! -e "$prefix" ]] || fail "installer dry-run wrote prefix"
[[ ! -e "$HOME/.local/bin" ]] || fail "installer dry-run wrote command directory"

"$installer" --user
[[ -x "$prefix/bin/omarchy-agent" ]] || fail "installer did not copy agent command"
[[ -x "$prefix/libexec/kubuntu-agent-terminal" ]] || fail "installer did not copy libexec adapter"
if find "$prefix" -type f \( -name '*.pyc' -o -path '*/__pycache__/*' \) -print -quit | grep -q .; then
  fail "installer copied generated Python bytecode"
fi
[[ -L "$HOME/.local/bin/omarchy-agent" ]] || fail "installer did not create command link"
[[ $(readlink -f "$HOME/.local/bin/omarchy-agent") == "$prefix/bin/omarchy-agent" ]] || fail "agent link points to wrong source"
[[ $(readlink -f "$HOME/.local/bin/kubuntu-agent-terminal") == "$prefix/libexec/kubuntu-agent-terminal" ]] || fail "libexec link points to wrong source"
[[ -L "$HOME/.agents/skills/omarchy" ]] || fail "installer did not install agent skills"
[[ -f "$HOME/.local/share/applications/omarchy-agent.desktop" ]] || fail "installer did not install global shortcut"
grep -Fq 'X-KDE-GlobalAccel-Shortcut=Meta+Shift+Ctrl+A' "$HOME/.local/share/applications/omarchy-agent.desktop" || fail "shortcut has wrong key"
[[ -f "$HOME/.config/systemd/user/omarchy-crash-watch.service" ]] || fail "installer did not install crash watcher unit"
[[ -f "$HOME/.config/systemd/user/omarchy-agent-usage-update.timer" ]] || fail "installer did not install usage timer unit"
grep -Fq -- 'daemon-reload' "$log_file" || fail "installer did not reload user systemd"
grep -Fq -- 'enable --now omarchy-agent-usage-update.timer' "$log_file" || fail "installer did not enable usage timer"

printf 'unrelated\n' >"$HOME/.local/bin/unrelated"
"$uninstaller" --user
[[ ! -e "$prefix" ]] || fail "uninstaller left the owned prefix"
[[ ! -e "$HOME/.local/bin/omarchy-agent" ]] || fail "uninstaller left an owned link"
[[ ! -e "$HOME/.local/share/applications/omarchy-agent.desktop" ]] || fail "uninstaller left the owned shortcut"
[[ -f "$HOME/.local/bin/unrelated" ]] || fail "uninstaller removed unrelated user file"

mkdir -p "$HOME/.local/bin"
printf 'user-owned\n' >"$HOME/.local/bin/omarchy-agent"
status=0
"$installer" --dry-run >/dev/null 2>&1 || status=$?
(( status != 0 )) || fail "installer overwrote a colliding command"
[[ $(<"$HOME/.local/bin/omarchy-agent") == "user-owned" ]] || fail "collision check changed existing command"

printf 'ok - installer, ownership manifest, collision guard, and rollback are verified\n'
