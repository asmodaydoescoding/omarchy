#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
agent_script="$repo_root/kubuntu/bin/omarchy-agent"
prompt_script="$repo_root/kubuntu/bin/omarchy-agent-prompt"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
log_file="$tmp_dir/log"
picker_log="$tmp_dir/picker"
mkdir -p "$fake_bin" "$tmp_dir/home"
: >"$log_file"

cat >"$fake_bin/omarchy-default-agent" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "${TEST_DEFAULT_AGENT:-}"
SCRIPT
cat >"$fake_bin/omarchy-cmd-missing" <<'SCRIPT'
#!/bin/bash
[[ ${1:-} == "${TEST_MISSING_AGENT:-}" ]]
SCRIPT
cat >"$fake_bin/kubuntu-agent-terminal" <<'SCRIPT'
#!/bin/bash
printf 'terminal' >>"$AGENT_LOG"
printf ' arg=%q' "$@" >>"$AGENT_LOG"
printf '\n' >>"$AGENT_LOG"
SCRIPT
cat >"$fake_bin/kubuntu-agent-picker" <<'SCRIPT'
#!/bin/bash
printf 'picker\n' >>"$PICKER_LOG"
SCRIPT

for name in pi omp opencode ori claude codex crush grok agy copilot; do
  cat >"$fake_bin/$name" <<'SCRIPT'
#!/bin/bash
printf '%s' "${0##*/}" >>"$AGENT_LOG"
printf ' arg=%q' "$@" >>"$AGENT_LOG"
printf '\n' >>"$AGENT_LOG"
SCRIPT
done
chmod +x "$fake_bin"/*

export HOME="$tmp_dir/home"
export PATH="$fake_bin:/usr/bin:/bin"
export AGENT_LOG="$log_file"
export PICKER_LOG="$picker_log"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$agent_script" ]] || fail "agent script is missing"
[[ -x "$prompt_script" ]] || fail "prompt script is missing"

assert_last() {
  local expected=$1
  local actual
  actual=$(python3 - "$log_file" <<'PY'
from pathlib import Path
import sys
lines=Path(sys.argv[1]).read_text().splitlines()
print(lines[-1] if lines else '')
PY
)
  [[ "$actual" == "$expected" ]] || fail "expected [$expected], got [$actual]"
}

run_non_inline() {
  local agent=$1
  shift
  : >"$log_file"
  TEST_DEFAULT_AGENT="$agent" "$agent_script" "$@"
}

run_inline() {
  local agent=$1
  shift
  : >"$log_file"
  TEST_DEFAULT_AGENT="$agent" "$agent_script" --inline "$@"
}

run_non_inline opencode
assert_last 'terminal arg=--app-id=org.omarchy.agent arg=opencode arg=--auto'
run_non_inline claude --prompt 'Review this project'
assert_last 'terminal arg=--app-id=org.omarchy.agent arg=claude arg=--permission-mode arg=auto arg=-- arg=Review\ this\ project'
run_non_inline crush --prompt 'Review this project'
assert_last 'terminal arg=--app-id=org.omarchy.agent arg=crush arg=run arg=Review\ this\ project'
run_non_inline ori --prompt 'Review this project'
assert_last 'terminal arg=--app-id=org.omarchy.agent arg=ori arg=code arg=--interactive arg=--prompt arg=Review\ this\ project'
run_inline copilot
assert_last 'copilot arg=--allow-all'
run_inline pi --prompt 'Review this project'
assert_last 'pi arg=Review\ this\ project'

: >"$picker_log"
TEST_DEFAULT_AGENT= "$agent_script" --pick
[[ $(<"$picker_log") == "picker" ]] || fail "--pick did not invoke the Kubuntu picker"

: >"$log_file"
if TEST_DEFAULT_AGENT=missing TEST_MISSING_AGENT=missing "$agent_script"; then
  fail "missing default command unexpectedly launched"
fi
[[ ! -s "$log_file" ]] || fail "missing default command launched an agent"

if TEST_DEFAULT_AGENT=opencode "$agent_script" Review this project >/dev/null 2>&1; then
  fail "positional prompt unexpectedly succeeded"
fi

printf 'ok - agent and prompt routing preserve source vectors and Kubuntu host seams\n'
