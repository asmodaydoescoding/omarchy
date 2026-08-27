#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
adapter="$repo_root/kubuntu/libexec/kubuntu-agent-terminal"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
work_dir="$tmp_dir/work dir"
log_file="$tmp_dir/konsole.log"
mkdir -p "$fake_bin" "$work_dir"

cat >"$fake_bin/konsole" <<'SCRIPT'
#!/bin/bash
set -Eeuo pipefail
: "${KONSOLE_LOG:?KONSOLE_LOG must be set}"
printf 'cwd=%q\n' "$PWD" >"$KONSOLE_LOG"
printf 'arg=%q\n' "$@" >>"$KONSOLE_LOG"
SCRIPT
chmod +x "$fake_bin/konsole"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

export PATH="$fake_bin:/usr/bin:/bin"
export KONSOLE_LOG="$log_file"

[[ -x "$adapter" ]] || fail "adapter is missing"

cd "$work_dir"
"$adapter" --app-id=org.omarchy.agent agent "hello world" 'arg=$HOME'

expected_cwd=$(printf '%q' "$work_dir")
grep -Fxq "cwd=$expected_cwd" "$log_file" || fail "adapter did not preserve the working directory"
grep -Fxq 'arg=--separate' "$log_file" || fail "adapter did not request a separate Konsole process"
grep -Fxq 'arg=--workdir' "$log_file" || fail "adapter did not pass Konsole workdir"
grep -Fxq "arg=$expected_cwd" "$log_file" || fail "adapter passed the wrong Konsole workdir"
grep -Fxq 'arg=-e' "$log_file" || fail "adapter did not use Konsole execute mode"
grep -Fxq 'arg=agent' "$log_file" || fail "adapter did not preserve the command"
grep -Fxq 'arg=hello\ world' "$log_file" || fail "adapter did not preserve a spaced argument"
grep -Fxq 'arg=arg=\$HOME' "$log_file" || fail "adapter did not preserve shell metacharacters"
if grep -Fq 'org.omarchy.agent' "$log_file"; then
  fail "adapter leaked the source app-id into the command argv"
fi

: >"$log_file"
if "$adapter" --app-id=org.omarchy.agent; then
  fail "adapter accepted a missing command"
fi
[[ ! -s "$log_file" ]] || fail "adapter invoked Konsole without a command"

printf 'ok - agent terminal preserves app-id, cwd, argv, and missing-command rejection\n'
