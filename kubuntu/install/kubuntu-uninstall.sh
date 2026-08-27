#!/bin/bash
set -Eeuo pipefail

prefix=${KUBUNTU_INSTALL_PREFIX:-$HOME/.local/share/omarchy-kubuntu-ai}
manifest="$prefix/install-manifest.tsv"
shortcut_helper="$prefix/libexec/kubuntu-global-shortcut"
mode=apply
if [[ ${1:-} == "--dry-run" ]]; then
  mode=dry-run
  shift
elif [[ ${1:-} == "--user" || -z ${1:-} ]]; then
  [[ -z ${1:-} ]] || shift
else
  echo "Usage: kubuntu-uninstall [--user|--dry-run]" >&2
  exit 1
fi

if [[ ! -f "$manifest" ]]; then
  printf 'Nothing installed under %s\n' "$prefix"
  exit 0
fi

if [[ $mode == dry-run ]]; then
  printf 'dry-run: disable omarchy-agent-usage-update.timer\n'
  while IFS=$'\t' read -r kind path target; do
    [[ -n "$kind" ]] || continue
    printf 'dry-run: remove %s %s\n' "$kind" "$path"
  done <"$manifest"
  exit 0
fi

systemctl --user disable --now omarchy-agent-usage-update.timer 2>/dev/null || true
while IFS=$'\t' read -r kind path target; do
  if [[ "$kind" == config && -x "$shortcut_helper" ]]; then
    "$shortcut_helper" remove "$path"
  fi
done <"$manifest"
while IFS=$'\t' read -r kind path target; do
  case "$kind" in
    file)
      rm -f -- "$path"
      ;;
    link)
      current=$(readlink -f "$path" 2>/dev/null || true)
      if [[ "$current" == "$target" ]]; then
        rm -f -- "$path"
      fi
      ;;
    package)
      kpackagetool6 --type Plasma/Applet --remove "$path" >/dev/null 2>&1 || true
      ;;
  esac
done <"$manifest"
rm -f -- "$manifest"
find "$prefix" -depth -type d -empty -delete 2>/dev/null || true
systemctl --user daemon-reload
printf 'Uninstalled Kubuntu Omarchy AI port\n'
