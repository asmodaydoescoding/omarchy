#!/bin/bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
package="$repo_root/kubuntu/plasma/omarchy-agents/package"
metadata="$package/metadata.json"
main="$package/contents/ui/main.qml"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

jq -e '.KPlugin.Id == "com.asmoday.omarchy.agents" and .KPackageStructure == "Plasma/Applet" and ."X-Plasma-API-Minimum-Version" == "6.0"' "$metadata" >/dev/null || fail "invalid Agents metadata"
grep -Fq 'PlasmoidItem' "$main" || fail "Agents entrypoint is not Plasma 6"
grep -Fq 'Plasma5Support.DataSource' "$main" || fail "usage data bridge is missing"
grep -Fq 'omarchy-agent-usage-update' "$main" || fail "usage refresh command is missing"
grep -Fq 'omarchy-agent-usage-list' "$main" || fail "usage aggregation command is missing"
grep -Fq 'Qt.RightButton' "$main" || fail "right-click launch is missing"
grep -Fq 'Qt.MiddleButton' "$main" || fail "middle-click provider switch is missing"
grep -Fq 'plasmoid.expanded = true' "$main" || fail "left-click panel behavior is missing"
grep -Fq 'Qt.Key_H' "$main" || fail "left keyboard provider navigation is missing"
grep -Fq 'Qt.Key_L' "$main" || fail "right keyboard provider navigation is missing"
grep -Fq 'TOKENS BY DAY' "$main" || fail "daily token section is missing"
grep -Fq 'TOKENS BY MODEL' "$main" || fail "model token section is missing"

kpackagetool6 --type Plasma/Applet --install "$package" >/dev/null
trap 'kpackagetool6 --type Plasma/Applet --remove com.asmoday.omarchy.agents >/dev/null 2>&1 || true' EXIT
kpackagetool6 --type Plasma/Applet --show com.asmoday.omarchy.agents >/dev/null || fail "Agents package was not installed"

printf 'ok - Omarchy Agents Plasma package metadata, bridge, interactions, and install are verified\n'
