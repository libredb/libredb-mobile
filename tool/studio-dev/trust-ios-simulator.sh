#!/usr/bin/env bash
# Makes an iOS simulator trust the local CA of tool/studio-dev/docker-compose.yml.
#
#   tool/studio-dev/trust-ios-simulator.sh [simulator udid]   # default: the booted simulator
#
# Unlike the Android emulator, an iOS simulator shares the Mac's network, so the stack's 127.0.0.1:8443 (Keycloak) and
# 127.0.0.1:9443 (Studio) are already reachable from the app as `localhost` — no port forwarding is needed. Only the
# CA has to be trusted. `simctl keychain add-root-cert` installs it in the simulator's trusted root store, which the
# app's HTTPS requests evaluate against.
#
# Needs: the studio-dev stack up (docker compose -f tool/studio-dev/docker-compose.yml up -d --wait), Xcode's simctl,
# and a booted simulator. The trust lasts until the keychain is reset or the simulator is erased, so run it once per
# simulator, and again after `docker compose down -v`, which deletes the CA and makes a new one. Never run in CI.
set -euo pipefail

compose_file="$(cd "$(dirname "$0")" && pwd)/docker-compose.yml"
device="${1:-booted}"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
ca_file="$work_dir/root.crt"

docker compose -f "$compose_file" cp ca-export:/ca/root.crt "$ca_file" 2>/dev/null

xcrun simctl keychain "$device" add-root-cert "$ca_file"

echo "Trusted the studio-dev CA on simulator '$device'. The stack's 127.0.0.1:8443 (Keycloak) and 9443 (Studio) are reachable as localhost; no port forwarding is needed."
