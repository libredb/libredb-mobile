#!/usr/bin/env bash
# Stops a store build that would carry a define meant for checks only (tool/release/check_only_defines.txt): one in
# the dart-defines file the build reads, or one set as a variable of the repository or of the job's GitHub environment.
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

# Exit 0 when the JSON object read from stdin has the key $1, 1 when it has not. Anything else, such as input that is
# not JSON or not an object, stops the script with exit 2, so a broken input never passes as "no such key".
has_key() {
  local status=0
  jq -e --arg name "$1" 'if type == "object" then has($name) else error("not a JSON object") end' > /dev/null ||
    status=$?
  case "$status" in
    0) return 0 ;;
    1) return 1 ;;
    *)
      echo "Could not read $2 as a JSON object (jq exit $status)."
      exit 2
      ;;
  esac
}

if [ ! -f "$1" ]; then
  echo "The defines file $1 does not exist."
  exit 2
fi

found=0
for name in $names; do
  if has_key "$name" "the defines file $1" < "$1"; then
    echo "The store build's defines carry $name, which is meant for checks only."
    found=1
  fi
  if has_key "$name" "RELEASE_VARS" <<< "$RELEASE_VARS"; then
    echo "The variable $name is set, but it is meant for checks only; delete it."
    found=1
  fi
done
if [ "$found" -ne 0 ]; then
  exit 1
fi
echo "No check-only define in the store build."
