#!/bin/bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
status_script="$root/kubuntu/ai-core/hermes-status"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fake_bin="$tmp/bin"
test_home="$tmp/home"
state_home="$test_home/state"
hermes_home="$test_home/hermes"
mkdir -p "$fake_bin" "$test_home" "$state_home/omarchy/agents/usage" "$hermes_home"

cat >"$fake_bin/hermes" <<'SCRIPT'
#!/bin/bash
if [[ ${1:-} == "--version" ]]; then
  printf '%s\n' "Hermes Agent v-test"
else
  exit 0
fi
SCRIPT

cat >"$fake_bin/systemctl" <<'SCRIPT'
#!/bin/bash
case "${SYSTEMCTL_MODE:-active}:$*" in
  active:*is-active*) exit 0 ;;
  enabled:*is-active*) exit 3 ;;
  enabled:*is-enabled*) exit 0 ;;
  *) exit 3 ;;
esac
SCRIPT

cat >"$fake_bin/hermes-node" <<'SCRIPT'
#!/bin/bash
if [[ ${HERMES_NODE_MODE:-live} == "live" ]]; then
  printf '%s\n' 'alpha: online' 'beta: offline'
elif [[ ${HERMES_NODE_MODE:-live} == "noise" ]]; then
  printf '%s\n' 'unparseable output'
fi
SCRIPT
chmod +x "$fake_bin/hermes" "$fake_bin/systemctl" "$fake_bin/hermes-node"

run_status() {
  HOME="$test_home" \
  XDG_STATE_HOME="$state_home" \
  HERMES_HOME="$hermes_home" \
  PATH="$fake_bin:/usr/bin:/bin" \
    "$status_script"
}

# Live install, gateway, model, session, and node state.
printf 'model: test/model\n' >"$hermes_home/config.yaml"
printf '%s\n' '{"currentSessionId":"session-1","currentSessionTitle":"Parity test","nodes":{"cached":{"online":true}},"nodesOnline":1,"nodesTotal":1}' >"$state_home/omarchy/agents/usage/hermes.json"
output=$(run_status)
printf '%s\n' "$output" | jq -e '
  .installed == true and
  .version == "Hermes Agent v-test" and
  .gatewayState == "active" and
  .activeModel == "test/model" and
  .currentSessionId == "session-1" and
  .currentSessionTitle == "Parity test" and
  .hermesNodeAvailable == true and
  .nodesOnline == 1 and
  .nodesTotal == 2 and
  .nodes.alpha.online == true and
  .nodes.beta.online == false'

# Enabled-but-stopped gateway state and cached nodes when live output has no rows.
export SYSTEMCTL_MODE=enabled
export HERMES_NODE_MODE=noise
output=$(run_status)
printf '%s\n' "$output" | jq -e '.gatewayState == "stopped" and .nodes.cached.online == true and .nodesOnline == 1 and .nodesTotal == 1'

# Invalid base data is ignored, and missing Hermes is reported safely.
printf '%s\n' 'not-json' >"$state_home/omarchy/agents/usage/hermes.json"
rm -f "$fake_bin/hermes"
output=$(run_status)
printf '%s\n' "$output" | jq -e '.installed == false and .gatewayState == "unknown" and .activeModel == "test/model" and .currentSessionId == ""'

# Missing user unit is reported as not-installed when Hermes exists.
cat >"$fake_bin/hermes" <<'SCRIPT'
#!/bin/bash
printf '%s\n' 'Hermes Agent v-test'
SCRIPT
chmod +x "$fake_bin/hermes"
export SYSTEMCTL_MODE=missing
output=$(run_status)
printf '%s\n' "$output" | jq -e '.installed == true and .gatewayState == "not-installed"'

printf 'hermes-status tests passed\n'
