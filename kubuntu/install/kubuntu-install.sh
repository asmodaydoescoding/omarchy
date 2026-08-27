#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
prefix=${KUBUNTU_INSTALL_PREFIX:-$HOME/.local/share/omarchy-kubuntu-ai}
manifest="$prefix/install-manifest.tsv"
mode=apply
if [[ ${1:-} == "--dry-run" ]]; then
  mode=dry-run
  shift
elif [[ ${1:-} == "--user" || -z ${1:-} ]]; then
  [[ -z ${1:-} ]] || shift
else
  echo "Usage: kubuntu-install [--user|--dry-run]" >&2
  exit 1
fi

source_files=()
while IFS= read -r path; do source_files+=("$path"); done < <(
  python3 - "$repo_root/kubuntu" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
for rel_root in ('bin','libexec','skills','voxtype','systemd'):
    base=root/rel_root
    if not base.exists():
        continue
    for path in sorted(base.rglob('*')):
        if path.is_file() and path.name != '.gitkeep':
            print(path)
PY
)

if ((${#source_files[@]} == 0)); then
  echo "No Kubuntu port files found" >&2
  exit 1
fi

for source in "${source_files[@]}"; do
  [[ -f "$source" ]] || { echo "Missing source file: $source" >&2; exit 1; }
done

user_bin="$HOME/.local/bin"
link_sources=()
while IFS= read -r path; do link_sources+=("$path"); done < <(
  for source in "$repo_root"/kubuntu/bin/* "$repo_root"/kubuntu/libexec/*; do
    [[ -f "$source" && $(basename "$source") != '.gitkeep' ]] || continue
    printf '%s\n' "$source"
  done
)

for source in "${link_sources[@]}"; do
  name=$(basename "$source")
  link="$user_bin/$name"
  relative=${source#"$repo_root/kubuntu/"}
  expected="$prefix/$relative"
  if [[ -e "$link" || -L "$link" ]]; then
    target=$(readlink -f "$link" 2>/dev/null || true)
    [[ "$target" == "$expected" ]] || { echo "Refusing to overwrite existing path: $link" >&2; exit 1; }
  fi
done

if [[ $mode == dry-run ]]; then
  printf 'dry-run: install %d user-local files under %s\n' "${#source_files[@]}" "$prefix"
  printf 'dry-run: create %d command links under %s\n' "${#link_sources[@]}" "$user_bin"
  printf 'dry-run: install skills into .agents, .claude, .codex, .pi, and .gemini\n'
  printf 'dry-run: install user systemd units and usage timer\n'
  exit 0
fi

mkdir -p "$prefix" "$user_bin"
: >"$manifest"
for source in "${source_files[@]}"; do
  relative=${source#"$repo_root/kubuntu/"}
  destination="$prefix/$relative"
  mkdir -p "$(dirname "$destination")"
  install -m "$(stat -c '%a' "$source")" "$source" "$destination"
  printf 'file\t%s\n' "$destination" >>"$manifest"
done

for source in "${link_sources[@]}"; do
  name=$(basename "$source")
  link="$user_bin/$name"
  relative=${source#"$repo_root/kubuntu/"}
  target="$prefix/$relative"
  ln -sfn "$target" "$link"
  printf 'link\t%s\t%s\n' "$link" "$target" >>"$manifest"
done

KUBUNTU_SKILLS_ROOT="$prefix/skills" "$prefix/bin/omarchy-install-agent-skills"

systemctl --user daemon-reload
systemctl --user enable --now omarchy-agent-usage-update.timer 2>/dev/null || true
printf 'Installed Kubuntu Omarchy AI port under %s\n' "$prefix"
