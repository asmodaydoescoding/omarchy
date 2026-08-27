#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
picker="$repo_root/kubuntu/libexec/kubuntu-agent-picker"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
menu_log="$tmp_dir/menu.log"
selection_log="$tmp_dir/selection.log"
mkdir -p "$fake_bin"

cat >"$fake_bin/kdialog" <<'SCRIPT'
#!/bin/bash
set -Eeuo pipefail
: "${MENU_LOG:?MENU_LOG must be set}"
printf 'arg=%q\n' "$@" >"$MENU_LOG"
if [[ ${KDE_PICKER_MODE:-select} == "cancel" ]]; then
  exit 1
fi
printf '%s\n' "${KDE_PICKER_SELECTION:-codex}"
SCRIPT

cat >"$fake_bin/omarchy-default-agent" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >>"$SELECTION_LOG"
SCRIPT
chmod +x "$fake_bin/kdialog" "$fake_bin/omarchy-default-agent"

export PATH="$fake_bin:/usr/bin:/bin"
export MENU_LOG="$menu_log"
export SELECTION_LOG="$selection_log"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$picker" ]] || fail "picker is missing"

KDE_PICKER_SELECTION=codex "$picker"
[[ $(<"$selection_log") == "codex" ]] || fail "picker did not forward the selected agent"
for key in pi omp opencode ori claude codex grok agy copilot crush; do
  grep -Fxq "arg=$key" "$menu_log" || fail "picker menu omitted $key"
done

grep -Fxq 'arg=--menu' "$menu_log" || fail "picker did not use kdialog menu mode"

: >"$selection_log"
if KDE_PICKER_MODE=cancel "$picker"; then
  fail "picker accepted cancellation"
fi
[[ ! -s "$selection_log" ]] || fail "picker invoked default-agent after cancellation"

: >"$selection_log"
if KDE_PICKER_SELECTION=unsupported "$picker"; then
  fail "picker accepted an unsupported selection"
fi
[[ ! -s "$selection_log" ]] || fail "picker forwarded an unsupported selection"

printf 'ok - KDE picker preserves source choices, selection, and cancellation\n'
