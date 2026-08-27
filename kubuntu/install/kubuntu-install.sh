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
for rel_root in ('ai-core','bin','libexec','skills','voxtype','systemd','plasma'):
    base=root/rel_root
    if not base.exists():
        continue
    for path in sorted(base.rglob('*')):
        if path.is_file() and path.name != '.gitkeep' and '__pycache__' not in path.parts and path.suffix != '.pyc':
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

desktop_source="$repo_root/kubuntu/install/kubuntu-global-shortcut.desktop"
desktop_destination="$HOME/.local/share/applications/omarchy-agent.desktop"
if [[ -e "$desktop_destination" ]] && ! cmp -s "$desktop_source" "$desktop_destination"; then
  echo "Refusing to overwrite existing path: $desktop_destination" >&2
  exit 1
fi

if [[ $mode == dry-run ]]; then
  printf 'dry-run: install %d user-local files under %s\n' "${#source_files[@]}" "$prefix"
  printf 'dry-run: create %d command links under %s\n' "${#link_sources[@]}" "$user_bin"
  printf 'dry-run: install skills into .agents, .claude, .codex, .pi, and .gemini\n'
  printf 'dry-run: install KDE global shortcut under %s\n' "$desktop_destination"
  printf 'dry-run: install Hermes Harness and Omarchy Agents Plasma packages\n'
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

user_unit_dir="$HOME/.config/systemd/user"
for unit_source in "$repo_root"/kubuntu/systemd/user/*; do
  [[ -f "$unit_source" ]] || continue
  unit_name=$(basename "$unit_source")
  unit_destination="$user_unit_dir/$unit_name"
  mkdir -p "$user_unit_dir"
  install -m 644 "$unit_source" "$unit_destination"
  printf 'file\t%s\n' "$unit_destination" >>"$manifest"
done

desktop_destination="$HOME/.local/share/applications/omarchy-agent.desktop"
mkdir -p "$(dirname "$desktop_destination")"
install -m 644 "$desktop_source" "$desktop_destination"
printf 'file\t%s\n' "$desktop_destination" >>"$manifest"

for source in "${link_sources[@]}"; do
  name=$(basename "$source")
  link="$user_bin/$name"
  relative=${source#"$repo_root/kubuntu/"}
  target="$prefix/$relative"
  ln -sfn "$target" "$link"
  printf 'link\t%s\t%s\n' "$link" "$target" >>"$manifest"
done

KUBUNTU_SKILLS_ROOT="$prefix/skills" "$prefix/bin/omarchy-install-agent-skills"

for package in hermes-harness omarchy-agents; do
  if [[ "$package" == "omarchy-agents" ]]; then
    package_id="com.asmoday.omarchy.agents"
  else
    package_id="com.asmoday.omarchy.hermes-harness"
  fi
  package_path="$prefix/plasma/$package/package"
  if kpackagetool6 --type Plasma/Applet --show "$package_id" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$package_path" >/dev/null
  else
    kpackagetool6 --type Plasma/Applet --install "$package_path" >/dev/null
  fi
  printf 'package\t%s\n' "$package_id" >>"$manifest"
done

systemctl --user daemon-reload
systemctl --user enable --now omarchy-agent-usage-update.timer 2>/dev/null || true
printf 'Installed Kubuntu Omarchy AI port under %s\n' "$prefix"
