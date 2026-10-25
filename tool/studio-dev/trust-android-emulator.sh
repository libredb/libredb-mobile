#!/usr/bin/env bash
# Makes an Android emulator trust the local CA of tool/studio-dev/docker-compose.yml and forwards the stack's ports.
#
#   tool/studio-dev/trust-android-emulator.sh [adb serial]
#
# The app's own requests (Dart's HttpClient) trust only the system CA store, never a user-installed certificate, so
# the CA has to be in /system/etc/security/cacerts. The script mounts a tmpfs copy of that directory with the CA
# added, which needs adb root: use an emulator image without Google Play (a "Google APIs" image) at API level 33 or
# lower. Android 14 and later read the system store from an APEX module, where this does not work.
#
# Nothing on the image changes: the mount and the port forwarding last until the emulator shuts down, so run the
# script after every emulator boot, and again after `docker compose down -v`, which deletes the CA.
set -euo pipefail

compose_file="$(cd "$(dirname "$0")" && pwd)/docker-compose.yml"
adb_cmd=(adb)
if [[ $# -gt 0 ]]; then adb_cmd=(adb -s "$1"); fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
ca_file="$work_dir/root.crt"

docker compose -f "$compose_file" cp ca-export:/ca/root.crt "$ca_file" 2>/dev/null
# Android names a CA file after the old OpenSSL subject hash.
hash="$(openssl x509 -inform PEM -subject_hash_old -in "$ca_file" -noout)"

sdk="$("${adb_cmd[@]}" shell getprop ro.build.version.sdk | tr -d '\r')"
if ((sdk >= 34)); then
  echo "API level $sdk reads the system CA store from an APEX module; use an emulator at API level 33 or lower." >&2
  exit 1
fi

"${adb_cmd[@]}" root >/dev/null
# adbd restarts as root, and the device is briefly offline while it does.
for _ in $(seq 1 30); do
  if [[ "$("${adb_cmd[@]}" shell id -u 2>/dev/null | tr -d '\r')" == 0 ]]; then break; fi
  sleep 1
done
if [[ "$("${adb_cmd[@]}" shell id -u 2>/dev/null | tr -d '\r')" != 0 ]]; then
  echo "adb root is not available: use an emulator image without Google Play." >&2
  exit 1
fi

"${adb_cmd[@]}" push "$ca_file" "/data/local/tmp/$hash.0" >/dev/null 2>&1
"${adb_cmd[@]}" shell "set -e
  store=/system/etc/security/cacerts
  copy=/data/local/tmp/studio-dev-cacerts
  rm -rf \$copy && mkdir -p \$copy
  cp \$store/* \$copy/
  mv /data/local/tmp/$hash.0 \$copy/
  if ! grep -q ' \$store tmpfs ' /proc/mounts; then mount -t tmpfs tmpfs \$store; fi
  cp \$copy/* \$store/
  chown root:root \$store/*
  chmod 644 \$store/*
  chcon u:object_r:system_file:s0 \$store/*
  rm -rf \$copy"
# A running browser keeps the store it loaded at start.
"${adb_cmd[@]}" shell am force-stop com.android.chrome

"${adb_cmd[@]}" reverse tcp:8443 tcp:8443 >/dev/null
"${adb_cmd[@]}" reverse tcp:9443 tcp:9443 >/dev/null
"${adb_cmd[@]}" reverse tcp:9444 tcp:9444 >/dev/null
"${adb_cmd[@]}" reverse tcp:9445 tcp:9445 >/dev/null

echo "Trusted the studio-dev CA as $hash.0 and forwarded ports 8443 (Keycloak), 9443 (Studio), 9444 (governed Studio) and 9445 (Platform)."
