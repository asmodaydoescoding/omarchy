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
shortcut_helper="$repo_root/kubuntu/libexec/kubuntu-global-shortcut"
shortcut_config="$HOME/.config/kglobalshortcutsrc"
link_sources=()
while IFS= read -r path; do link_sources+=("$path"); done < <(
  for source in "$repo_root"/kubuntu/bin/* "$repo_root"/kubuntu/libexec/*; do
    [[ -f "$source" && $(basename "$source") != '.gitkeep' && $(basename "$source") != 'kubuntu-global-shortcut' ]] || continue
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
service_source="$repo_root/kubuntu/install/kubuntu-global-shortcut-service.desktop"
desktop_destination="$HOME/.local/share/applications/omarchy-agent.desktop"
globalaccel_destination="$HOME/.local/share/kglobalaccel/omarchy-agent.desktop"
for destination in "$desktop_destination" "$globalaccel_destination"; do
  desktop_owned=false
  if [[ -f "$manifest" ]] && grep -Fqx $'file\t'"$destination" "$manifest"; then
    desktop_owned=true
  fi
  source="$desktop_source"
  [[ "$destination" == "$globalaccel_destination" ]] && source="$service_source"
  if [[ -e "$destination" ]] && ! cmp -s "$source" "$destination" && [[ "$desktop_owned" != true ]]; then
    echo "Refusing to overwrite existing path: $destination" >&2
    exit 1
  fi
done
"$shortcut_helper" validate "$shortcut_config"

if [[ $mode == dry-run ]]; then
  printf 'dry-run: install %d user-local files under %s\n' "${#source_files[@]}" "$prefix"
  printf 'dry-run: create %d command links under %s\n' "${#link_sources[@]}" "$user_bin"
  printf 'dry-run: install skills into .agents, .claude, .codex, .pi, and .gemini\n'
  printf 'dry-run: install KDE global shortcut under %s\n' "$desktop_destination"
  printf 'dry-run: install KDE global-shortcut service under %s\n' "$globalaccel_destination"
  printf 'dry-run: register KDE shortcut stanza under %s\n' "$shortcut_config"
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
globalaccel_destination="$HOME/.local/share/kglobalaccel/omarchy-agent.desktop"
mkdir -p "$(dirname "$globalaccel_destination")"
install -m 644 "$service_source" "$globalaccel_destination"
printf 'file\t%s\n' "$globalaccel_destination" >>"$manifest"
"$shortcut_helper" ensure "$shortcut_config"
printf 'config\t%s\tservices][omarchy-agent.desktop\n' "$shortcut_config" >>"$manifest"

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
