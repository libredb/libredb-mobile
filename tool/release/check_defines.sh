#!/usr/bin/env bash
# Stops a store build that would carry a define meant for checks only (tool/release/check_only_defines.txt): one in
# the dart-defines file the build reads, or one set as a variable of the repository or of the job's GitHub environment.
# It also stops one whose PROD_API_URL, OIDC_ISSUER, SENTRY_DSN or PLATFORM_API_URL is set but is not an https URL, the
# rule a prod start applies (AppConfig.httpsOnlyDefines, docs/security.md "Encryption in transit"); it names the define,
# never its value. The release passes PLATFORM_API_URL and PLATFORM_CERT_PINS only when the owner sets them as variables.
# It also stops one whose STUDIO_CERT_PINS, OIDC_CERT_PINS or PLATFORM_CERT_PINS breaks a pin rule of a prod start
# (AppConfig._pins, docs/security.md "Certificate pinning"), or that sets PLATFORM_CERT_PINS without PLATFORM_API_URL;
# it names the define and the rule, never a pin.
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

# An absolute https URL with a host, verbatim the pattern of AppConfig.isHttpsUrl and NativeSentry.requireHttpsDsn.
# OIDC_ISSUER is trimmed first, as the sign-in reads it; PROD_API_URL, SENTRY_DSN and PLATFORM_API_URL are refused with
# surrounding whitespace, as a prod start refuses them.
https_url='^[Hh][Tt][Tt][Pp][Ss]://([^/?#@\x00-\x20\x7F]*@)?(\[[0-9A-Fa-f:.]+\]|[^/?#@:\[\]\x00-\x20\x7F]+)(:[0-9]*)?([/?#]|$)'
for name in PROD_API_URL OIDC_ISSUER SENTRY_DSN PLATFORM_API_URL; do
  status=0
  verdict=$(jq -r --arg name "$name" --arg pattern "$https_url" '
    if has($name) | not then "ok"
    elif (.[$name] | type) != "string" then "not-https"
    else .[$name] as $raw
      | ($raw | sub("^\\s+"; "") | sub("\\s+$"; "")) as $trimmed
      | if $name == "OIDC_ISSUER" then (if ($trimmed | test($pattern)) then "ok" else "not-https" end)
        elif $raw != $trimmed then "whitespace"
        elif ($raw | test($pattern)) then "ok"
        else "not-https" end
    end' "$1" 2> /dev/null) || status=$?
  if [ "$status" -ne 0 ]; then
    echo "Could not read $name from the defines file $1 (jq exit $status)."
    exit 2
  fi
  case "$verdict" in
    ok) ;;
    whitespace)
      echo "$name has leading or trailing whitespace; the store build needs an https URL (docs/security.md, \"Encryption in transit\")."
      found=1
      ;;
    *)
      echo "$name must be an https URL in the store build (docs/security.md, \"Encryption in transit\")."
      found=1
      ;;
  esac
done

# A pin is the canonical padded base64 of a 32-byte SHA-256: 43 characters carry 258 bits, so the last one before the
# "=" has its two low bits zero. jq alone checks it, so the script behaves the same on Linux and macOS.
pin='^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$'
for name in STUDIO_CERT_PINS OIDC_CERT_PINS PLATFORM_CERT_PINS; do
  status=0
  # One broken rule per line. Absent, or only whitespace, is no pins, as a prod start reads it.
  rules=$(jq -r --arg name "$name" --arg pin "$pin" '
    def strip: sub("^\\s+"; "") | sub("\\s+$"; "");
    def empty_define($n): (has($n) | not) or .[$n] == "";
    if has($name) | not then empty
    elif (.[$name] | type) != "string" then "must be a string"
    elif (.[$name] | strip) == "" then empty
    elif $name == "PLATFORM_CERT_PINS" and empty_define("PLATFORM_API_URL") then
      "is set, but PLATFORM_API_URL is empty, so no host uses it"
    else (.[$name] | split(",") | map(strip)) as $pins
      | [$pins | to_entries[] | select(.value | test($pin) | not)
          | "has entry \(.key + 1), which is not a base64 SHA-256 pin of 44 characters ending in ="] as $bad
      | if ($bad | length) > 0 then $bad[]
        elif ($pins | unique | length) < 2 then "needs at least two distinct pins, the current key and a backup key"
        else empty end
    end' "$1" 2> /dev/null) || status=$?
  if [ "$status" -ne 0 ]; then
    echo "Could not read $name from the defines file $1 (jq exit $status)."
    exit 2
  fi
  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    echo "$name $rule (docs/security.md, \"Certificate pinning\")."
    found=1
  done <<< "$rules"
done

if [ "$found" -ne 0 ]; then
  exit 1
fi
echo "No check-only define, no non-https URL and no pin define that breaks a rule in the store build."
