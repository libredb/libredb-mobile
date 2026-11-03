#!/usr/bin/env bash
# Runs an on-device LOCAL twin (integration_test/app_local_*_test.dart) against the tool/studio-dev stack on an iOS
# SIMULATOR, with a real seeded session, and writes its screenshots to build/screenshots/.
#
#   scripts/on-device-local-twin-ios.sh [test-file] [simulator-udid] [studio-dev-user]
#   scripts/on-device-local-twin-ios.sh                      # the connections twin, the booted simulator, user admin
#
# The iOS sibling of scripts/on-device-local-twin.sh. The simulator shares the Mac's network, so studio-dev's
# 127.0.0.1 ports need no forwarding; only the CA is trusted (trust-ios-simulator.sh). It signs in to the studio-dev
# Keycloak once with the authorization-code flow (as access-token.sh does), hands the tokens to main_local through
# --dart-define=SEED_SESSION, then drives the test. The seeded access token is already expired by the time the build
# finishes, so the app refreshes it from the seeded refresh token at startup; the refresh token lives long enough to
# cover the build.
#
# Needs: the studio-dev stack up (docker compose -f tool/studio-dev/docker-compose.yml up -d --wait), a booted iOS
# simulator, Xcode, curl, openssl, python3, and fvm. Never run in CI.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

target="${1:-integration_test/app_local_connections_test.dart}"
udid="${2:-}"
user="${3:-admin}"

if [[ -z "$udid" ]]; then
  udid="$(xcrun simctl list devices booted -j |
    python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; ids=[x["udid"] for v in d.values() for x in v if x.get("state")=="Booted"]; print(ids[0] if ids else "")')"
fi
[[ -n "$udid" ]] || { echo "No booted iOS simulator; boot one with: xcrun simctl boot 'iPhone 17'" >&2; exit 1; }

fvm="$HOME/fvm/bin/fvm"

echo "==> Trusting the studio-dev CA on simulator $udid"
tool/studio-dev/trust-ios-simulator.sh "$udid"

echo "==> Signing in to the studio-dev Keycloak as '$user' (authorization-code + PKCE)"
kc=https://localhost:8443/realms/libredb/protocol/openid-connect
redirect='org.libredb.mobile:/oauth2redirect'
jar="$(mktemp)"; trap 'rm -f "$jar"' EXIT
verifier="$(head -c 48 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')"
challenge="$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=\n')"
page="$(curl -skf -c "$jar" -b "$jar" -G "$kc/auth" \
  --data-urlencode client_id=libredb-mobile --data-urlencode response_type=code --data-urlencode scope=openid \
  --data-urlencode "redirect_uri=$redirect" --data-urlencode state=twin \
  --data-urlencode code_challenge_method=S256 --data-urlencode "code_challenge=$challenge")"
action="$(printf '%s' "$page" | { grep -o 'id="kc-form-login"[^>]*action="[^"]*"' || true; } |
  sed 's/.*action="//;s/"$//;s/&amp;/\&/g')"
[ -n "$action" ] || { echo "Keycloak sign-in page has no login form" >&2; exit 1; }
location="$(curl -sk -c "$jar" -b "$jar" -o /dev/null -w '%{redirect_url}' "$action" \
  --data-urlencode "username=$user" --data-urlencode "password=$user" --data-urlencode credentialId=)"
code="$(printf '%s' "$location" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')"
[ -n "$code" ] || { echo "Keycloak returned no code for $user" >&2; exit 1; }
tokens="$(curl -skf "$kc/token" --data-urlencode grant_type=authorization_code --data-urlencode client_id=libredb-mobile \
  --data-urlencode "code=$code" --data-urlencode "redirect_uri=$redirect" --data-urlencode "code_verifier=$verifier")"
access="$(printf '%s' "$tokens" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
refresh="$(printf '%s' "$tokens" | python3 -c 'import json,sys; print(json.load(sys.stdin)["refresh_token"])')"
idtok="$(printf '%s' "$tokens" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id_token",""))')"
echo "==> Got a session (access ${#access}B, refresh ${#refresh}B); seeding it into $target"

"$fvm" flutter drive \
  --driver test_driver/integration_test.dart \
  --target "$target" \
  -d "$udid" \
  --dart-define-from-file=tool/studio-dev/studio-dev.env \
  --dart-define=SEED_SESSION=true \
  --dart-define=SEED_SESSION_TARGET=studio \
  --dart-define=SEED_ACCESS_TOKEN="$access" \
  --dart-define=SEED_REFRESH_TOKEN="$refresh" \
  --dart-define=SEED_ID_TOKEN="$idtok"

echo "==> Done. Screenshots in build/screenshots/"
