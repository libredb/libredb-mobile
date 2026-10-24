#!/usr/bin/env bash
# Uploads the Dart obfuscation map of a release build to Sentry once for each Android symbols file of the build
# (docs/release.md, "Crash symbols"), and fails on any error: sentry_dart_plugin would only log a failed map upload.
# Sentry refuses a map whose content it already holds, so each upload starts with the debug id of its symbols file, as
# the plugin does; the map itself is not changed. sentry-cli reads SENTRY_ORG, SENTRY_PROJECT and SENTRY_AUTH_TOKEN
# from the environment.
# Usage: tool/release/upload_dart_symbol_map.sh <sentry-cli> <obfuscation map> <split-debug-info directory>
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <sentry-cli> <obfuscation map> <split-debug-info directory>"
  exit 2
fi
cli=$1
map=$2
dir=$3

if [ ! -f "$map" ]; then
  echo "The obfuscation map $map does not exist."
  exit 1
fi
shopt -s nullglob
symbols=("$dir"/app.android-*.symbols)
if [ "${#symbols[@]}" -eq 0 ]; then
  echo "No app.android-*.symbols file in $dir, so there is nothing to pair the obfuscation map with."
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for file in "${symbols[@]}"; do
  if ! id=$("$cli" debug-files check --json "$file" | jq -er '.variants[0].debug_id | strings'); then
    echo "Could not read the debug id of $file."
    exit 1
  fi
  jq -c --arg id "$id" '["SENTRY_DEBUG_ID_MARKER", $id] + .' "$map" > "$work/obfuscation.map.json"
  "$cli" dart-symbol-map upload "$work/obfuscation.map.json" "$file"
  echo "Uploaded the obfuscation map for $(basename "$file") (debug id $id)."
done
