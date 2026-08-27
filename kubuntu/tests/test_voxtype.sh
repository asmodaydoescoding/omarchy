#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
export HOME="$tmp_dir/home"
export LOG="$tmp_dir/log"
mkdir -p "$HOME" "$tmp_dir/bin"
: >"$LOG"

cat >"$tmp_dir/bin/kubuntu-agent-terminal" <<'SCRIPT'
#!/bin/bash
printf 'terminal' >>"$LOG"
printf ' arg=%q' "$@" >>"$LOG"
printf '\n' >>"$LOG"
SCRIPT
chmod +x "$tmp_dir/bin/kubuntu-agent-terminal"
export PATH="$tmp_dir/bin:/usr/bin:/bin"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

for name in install remove; do
  script="$repo_root/kubuntu/bin/omarchy-voxtype-$name"
  [[ -x "$script" ]] || fail "missing voxtype $name command"
  bash -n "$script"
done
for name in config model status; do
  script="$repo_root/kubuntu/bin/omarchy-voxtype-$name"
  [[ -x "$script" ]] || fail "missing voxtype $name command"
  bash -n "$script"
done

output=$("$repo_root/kubuntu/bin/omarchy-voxtype-install" --dry-run)
grep -Fq 'voxtype_0.7.1-1_amd64.deb' <<<"$output" || fail "install omitted official Voxtype artifact"
grep -Fq 'dry-run:' <<<"$output" || fail "install did not remain dry-run"
output=$("$repo_root/kubuntu/bin/omarchy-voxtype-remove" --dry-run)
grep -Fq 'dry-run:' <<<"$output" || fail "remove did not remain dry-run"

status=$("$repo_root/kubuntu/bin/omarchy-voxtype-status")
printf '%s\n' "$status" | jq -e '.class == "idle" and .alt == "" and .tooltip == ""' >/dev/null || fail "missing Voxtype did not emit idle JSON"

: >"$LOG"
"$repo_root/kubuntu/bin/omarchy-voxtype-model"
grep -Fq 'arg=--app-id=org.omarchy.agent' "$LOG" || fail "model command omitted app-id"
grep -Fq 'arg=voxtype' "$LOG" || fail "model command omitted voxtype"
grep -Fq 'arg=setup' "$LOG" || fail "model command omitted setup"
grep -Fq 'arg=model' "$LOG" || fail "model command omitted model"

: >"$LOG"
"$repo_root/kubuntu/bin/omarchy-voxtype-config"
grep -Fq 'arg=configure' "$LOG" || fail "config command omitted configure"

cmp -s "$repo_root/kubuntu/voxtype/config.toml" "$repo_root/default/voxtype/config.toml" || fail "Voxtype config diverges from source"

status=0
"$repo_root/kubuntu/bin/omarchy-capture-text" >/dev/null 2>&1 || status=$?
[[ "$status" == 2 ]] || fail "OCR gap did not return explicit unsupported status"
[[ ! -e "$HOME/.local/share/omarchy-kubuntu-ai" ]] || fail "dry-run Voxtype operations wrote state"

printf 'ok - Voxtype install, status, config, model, removal, and OCR gap are explicit\n'
