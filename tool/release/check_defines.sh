#!/usr/bin/env bash
# Stops a store build that would carry a define meant for checks only (tool/release/check_only_defines.txt): one in
# the dart-defines file the build reads, or one set as a repository or environment variable.
# Usage: RELEASE_VARS='<the variables as a JSON object>' tool/release/check_defines.sh <dart-defines.json>
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: RELEASE_VARS='<JSON object>' $0 <dart-defines.json>"
  exit 2
fi
if [ -z "${RELEASE_VARS:-}" ]; then
  echo "RELEASE_VARS is not set; pass the workflow's variables as JSON."
  exit 2
fi

list="$(dirname "$0")/check_only_defines.txt"
names=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$list" | sed '/^$/d')
if [ -z "$names" ]; then
  echo "$list names no define."
  exit 2
fi

found=0
for name in $names; do
  if jq -e --arg name "$name" 'has($name)' "$1" > /dev/null; then
    echo "The store build's defines carry $name, which is meant for checks only."
    found=1
  fi
  if printf '%s' "$RELEASE_VARS" | jq -e --arg name "$name" 'has($name)' > /dev/null; then
    echo "The variable $name is set, but it is meant for checks only; delete it."
    found=1
  fi
done
if [ "$found" -ne 0 ]; then
  exit 1
fi
echo "No check-only define in the store build."
