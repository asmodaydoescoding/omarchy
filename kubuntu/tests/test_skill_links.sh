#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
installer="$repo_root/kubuntu/bin/omarchy-install-agent-skills"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

skills_root="$tmp_dir/skills"
test_home="$tmp_dir/home"
mkdir -p "$skills_root/omarchy" "$skills_root/diagnose-crash" "$test_home"
printf 'omarchy\n' >"$skills_root/omarchy/SKILL.md"
printf 'diagnose\n' >"$skills_root/diagnose-crash/SKILL.md"

export HOME="$test_home"
export KUBUNTU_SKILLS_ROOT="$skills_root"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

[[ -x "$installer" ]] || fail "skill installer is missing"

for target in .agents/skills .claude/skills .codex/skills .pi/agent/skills .gemini/config/skills; do
  [[ ! -e "$HOME/$target" ]] || fail "test home was not isolated"
done

"$installer"
for target in .agents/skills .claude/skills .codex/skills .pi/agent/skills .gemini/config/skills; do
  for skill in omarchy diagnose-crash; do
    link="$HOME/$target/$skill"
    [[ -L "$link" ]] || fail "missing symlink $link"
    [[ $(readlink "$link") == "$skills_root/$skill" ]] || fail "wrong target for $link"
  done
done

# Re-running is idempotent and does not turn links into copied directories.
"$installer"
for target in .agents/skills .claude/skills .codex/skills .pi/agent/skills .gemini/config/skills; do
  [[ -L "$HOME/$target/omarchy" ]] || fail "idempotent run changed omarchy link"
done

printf 'ok - agent skill links cover every source target and are idempotent\n'
