#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
installer="$repo_root/kubuntu/ai-core/omarchy-mise-install"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fake_bin="$tmp_dir/fake-bin"
mkdir -p -- "$fake_bin"
log_file="$tmp_dir/mise.log"
: > "$log_file"

cat > "$fake_bin/mise" <<'EOF'
#!/bin/bash
set -Eeuo pipefail

: "${FAKE_MISE_LOG:?FAKE_MISE_LOG must be set}"

command=${1-}
{
printf 'minimum_release_age=%q' "${MISE_MINIMUM_RELEASE_AGE-}"
printf ' command=%q' "$command"
shift || true
for arg in "$@"; do
  printf ' arg=%q' "$arg"
done
printf '\n'
} >> "$FAKE_MISE_LOG"

case "$command" in
  use|x)
    exit 0
    ;;
  *)
    exit 64
    ;;
esac
EOF
chmod +x -- "$fake_bin/mise"

export HOME="$tmp_dir/home"
export PATH="$fake_bin:$PATH"
export FAKE_MISE_LOG="$log_file"
mkdir -p -- "$HOME/.local/bin"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local expected=$1
  local file=$2
  grep -Fqx -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_file_not_contains_any() {
  local file=$1
  shift
  local token
  for token in "$@"; do
    if grep -Fq -- "$token" "$file"; then
      fail "found forbidden token '$token' in $file"
    fi
  done
}

# The installer must create a default-name wrapper for a package.
"$installer" node@22
wrapper_default="$HOME/.local/bin/node@22"
[[ -x "$wrapper_default" ]] || fail "default wrapper is not executable"
"$wrapper_default" --version 'hello world'

# Explicit command and binary names must be preserved independently.
"$installer" python@3.12 py312 python
wrapper_explicit="$HOME/.local/bin/py312"
[[ -x "$wrapper_explicit" ]] || fail "explicit wrapper is not executable"
"$wrapper_explicit" -c 'print("hello world")' '--flag=$HOME'

expected_use_default='minimum_release_age=0 command=use arg=-g arg=--quiet arg=node@22'
expected_x_default='minimum_release_age=0 command=x arg=node@22 arg=-- arg=node@22 arg=--version arg=hello\ world'
expected_use_explicit='minimum_release_age=0 command=use arg=-g arg=--quiet arg=python@3.12'
expected_x_explicit='minimum_release_age=0 command=x arg=python@3.12 arg=-- arg=python arg=-c arg=print\(\"hello\ world\"\) arg=--flag=\$HOME'
assert_file_contains "$expected_use_default" "$log_file"
assert_file_contains "$expected_x_default" "$log_file"
assert_file_contains "$expected_use_explicit" "$log_file"
assert_file_contains "$expected_x_explicit" "$log_file"

# Re-running a wrapper with the same command name must recreate it cleanly.
printf 'stale wrapper\n' > "$wrapper_default"
"$installer" node@22
[[ -x "$wrapper_default" ]] || fail "recreated wrapper is not executable"
if grep -Fq -- 'stale wrapper' "$wrapper_default"; then
  fail "installer did not recreate an existing wrapper"
fi

# A missing package argument is an error and must not touch the log.
log_before_missing=$(wc -l < "$log_file")
if "$installer"; then
  fail "missing package unexpectedly succeeded"
fi
log_after_missing=$(wc -l < "$log_file")
[[ "$log_after_missing" == "$log_before_missing" ]] || fail "missing package invoked mise"

# Generated wrappers contain no credential or token material.
assert_file_not_contains_any "$wrapper_default" \
  'token' 'TOKEN' 'credential' 'CREDENTIAL' 'password' 'PASSWORD' \
  'secret' 'SECRET' 'api_key' 'API_KEY' 'Bearer'
assert_file_not_contains_any "$wrapper_explicit" \
  'token' 'TOKEN' 'credential' 'CREDENTIAL' 'password' 'PASSWORD' \
  'secret' 'SECRET' 'api_key' 'API_KEY' 'Bearer'

printf 'ok - mise wrappers create, execute, recreate, and reject missing packages\n'
