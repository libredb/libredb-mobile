#!/usr/bin/env bash
# Runs an on-device LOCAL twin (integration_test/app_local_*_test.dart) against the tool/studio-dev stack, with a real
# seeded session, and writes its screenshots to build/screenshots/.
#
#   scripts/on-device-local-twin.sh [test-file] [emulator-serial] [studio-dev-user]
#   scripts/on-device-local-twin.sh                      # the connections twin, emulator-5554, user admin
#
# It signs in to the studio-dev Keycloak once with the authorization-code flow (as access-token.sh does), hands the
# tokens to main_local through --dart-define=SEED_SESSION, trusts the studio-dev CA and forwards its ports on the
# emulator, then drives the test. The seeded access token is already expired by the time the build finishes, so the
# app refreshes it from the seeded refresh token at startup; the refresh token lives long enough to cover the build.
#
# Needs: the studio-dev stack up (docker compose -f tool/studio-dev/docker-compose.yml up -d --wait), a booted
# emulator on a Google APIs image at API <= 33 (adb root), curl, openssl, python3, and fvm. Never run in CI.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

target="${1:-integration_test/app_local_connections_test.dart}"
serial="${2:-emulator-5554}"
user="${3:-admin}"

# Put the SDK platform-tools on PATH so bare `adb` works here and inside trust-android-emulator.sh.
command -v adb >/dev/null 2>&1 || export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
fvm="$HOME/fvm/bin/fvm"

echo "==> Trusting the studio-dev CA and forwarding its ports on $serial"
tool/studio-dev/trust-android-emulator.sh "$serial"

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
  -d "$serial" \
  --dart-define-from-file=tool/studio-dev/studio-dev.env \
  --dart-define=SEED_SESSION=true \
  --dart-define=SEED_SESSION_TARGET=studio \
  --dart-define=SEED_ACCESS_TOKEN="$access" \
  --dart-define=SEED_REFRESH_TOKEN="$refresh" \
  --dart-define=SEED_ID_TOKEN="$idtok"

echo "==> Done. Screenshots in build/screenshots/"
