#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
default_agent="$repo_root/kubuntu/bin/omarchy-default-agent"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
test_home="$tmp_dir/home"
log_file="$tmp_dir/log"
mkdir -p "$fake_bin" "$test_home"
: >"$log_file"

cat >"$fake_bin/mise" <<'SCRIPT'
#!/bin/bash
printf 'mise' >>"$AGENT_LOG"
printf ' arg=%q' "$@" >>"$AGENT_LOG"
printf '\n' >>"$AGENT_LOG"
if [[ ${1:-} == "where" ]]; then
  [[ ${TEST_MISE_INSTALLED:-false} == "true" ]]
elif [[ ${1:-} == "use" && ${TEST_MISE_FAIL:-false} == "true" ]]; then
  exit 1
fi
SCRIPT
cat >"$fake_bin/kubuntu-agent-terminal" <<'SCRIPT'
#!/bin/bash
printf 'terminal' >>"$AGENT_LOG"
printf ' arg=%q' "$@" >>"$AGENT_LOG"
printf '\n' >>"$AGENT_LOG"
SCRIPT
cat >"$fake_bin/omarchy-agent" <<'SCRIPT'
#!/bin/bash
printf 'agent' >>"$AGENT_LOG"
printf ' arg=%q' "$@" >>"$AGENT_LOG"
printf '\n' >>"$AGENT_LOG"
SCRIPT
chmod +x "$fake_bin"/*

export HOME="$test_home"
export PATH="$fake_bin:/usr/bin:/bin"
export AGENT_LOG="$log_file"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$default_agent" ]] || fail "default-agent command is missing"

[[ -z $("$default_agent") ]] || fail "default agent is not initially unset"

TEST_MISE_INSTALLED=true "$default_agent" codex
[[ $(<"$HOME/.config/omarchy/defaults/agent") == "codex" ]] || fail "codex selection was not persisted"
grep -Fq 'mise arg=use arg=-g arg=codex' "$log_file" || fail "codex selection did not activate mise"
grep -Fq 'agent' "$log_file" || fail "installed codex did not launch the agent"

: >"$log_file"
TEST_MISE_INSTALLED=true "$default_agent" oh-my-pi
[[ $(<"$HOME/.config/omarchy/defaults/agent") == "omp" ]] || fail "oh-my-pi alias did not persist omp"
grep -Fq 'mise arg=where arg=github:can1357/oh-my-pi' "$log_file" || fail "oh-my-pi alias used the wrong mise package"

: >"$log_file"
rm -f "$HOME/.config/omarchy/defaults/agent"
TEST_MISE_INSTALLED=false "$default_agent" codex
[[ ! -e "$HOME/.config/omarchy/defaults/agent" ]] || fail "missing agent was persisted before installation"
grep -Fq 'terminal arg=--app-id=org.omarchy.agent arg=omarchy-default-agent arg=--install arg=codex' "$log_file" || fail "missing agent did not open the Kubuntu installer terminal"

: >"$log_file"
TEST_MISE_INSTALLED=false "$default_agent" --install codex
[[ $(<"$HOME/.config/omarchy/defaults/agent") == "codex" ]] || fail "explicit install did not persist codex"
grep -Fq 'mise arg=use arg=-g arg=codex' "$log_file" || fail "explicit install did not use mise"
grep -Fq 'agent arg=--inline' "$log_file" || fail "explicit install did not launch inline"

: >"$log_file"
printf '%s\n' claude >"$HOME/.config/omarchy/defaults/agent"
TEST_MISE_INSTALLED=true TEST_MISE_FAIL=true "$default_agent" codex >/dev/null 2>&1 && fail "mise failure unexpectedly succeeded"
[[ $(<"$HOME/.config/omarchy/defaults/agent") == "claude" ]] || fail "mise failure changed the existing default"
! grep -Fq 'agent ' "$log_file" || fail "mise failure launched an agent"

: >"$log_file"
TEST_MISE_INSTALLED=true "$default_agent" unsupported >/dev/null 2>&1 && fail "unsupported agent unexpectedly succeeded"
[[ $(<"$HOME/.config/omarchy/defaults/agent") == "claude" ]] || fail "unsupported agent changed the default"
! grep -Fq 'agent ' "$log_file" || fail "unsupported agent launched an agent"

printf 'ok - default-agent state, mise install, aliases, and failure paths\n'
