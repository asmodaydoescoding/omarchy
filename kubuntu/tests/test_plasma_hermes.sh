#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
package="$repo_root/kubuntu/plasma/hermes-harness/package"
metadata="$package/metadata.json"
main="$package/contents/ui/main.qml"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

jq -e '.KPlugin.Id == "com.asmoday.omarchy.hermes-harness" and .KPackageStructure == "Plasma/Applet" and ."X-Plasma-API-Minimum-Version" == "6.0"' "$metadata" >/dev/null || fail "invalid Plasma metadata"
grep -Fq 'PlasmoidItem' "$main" || fail "Plasma 6 entrypoint is not PlasmoidItem"
grep -Fq 'Plasma5Support.DataSource' "$main" || fail "status bridge is missing"
grep -Fq 'statusCommand: "hermes-status"' "$main" || fail "status command is not fixed"
grep -Fq 'Qt.RightButton' "$main" || fail "right-click launch is missing"
grep -Fq 'Qt.MiddleButton' "$main" || fail "middle-click refresh is missing"
grep -Fq 'plasmoid.expanded = true' "$main" || fail "left-click panel behavior is missing"

preexisting=0
if kpackagetool6 --type Plasma/Applet --show com.asmoday.omarchy.hermes-harness >/dev/null 2>&1; then
  preexisting=1
  kpackagetool6 --type Plasma/Applet --upgrade "$package" >/dev/null
else
  kpackagetool6 --type Plasma/Applet --install "$package" >/dev/null
fi
if ((preexisting == 0)); then
  trap 'kpackagetool6 --type Plasma/Applet --remove com.asmoday.omarchy.hermes-harness >/dev/null 2>&1 || true' EXIT
fi
kpackagetool6 --type Plasma/Applet --show com.asmoday.omarchy.hermes-harness >/dev/null || fail "Plasma package was not installed"

printf 'ok - Hermes Harness Plasma package metadata, bridge, interactions, and install are verified\n'
