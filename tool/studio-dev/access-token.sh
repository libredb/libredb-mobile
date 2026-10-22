#!/usr/bin/env bash
# Prints an access token of the libredb-mobile client for a user of the studio-dev realm, signed in the way the app
# signs in: the authorization code flow with PKCE against Keycloak's login form. For recording Studio answers with
# curl (docs/studio.md). NOT FOR PRODUCTION: it posts the realm's committed dev passwords.
#
#   tool/studio-dev/access-token.sh admin        # or user
#
# Needs curl, openssl and python3. The token lives 60 seconds, as every token of the realm does.
set -euo pipefail

user="${1:?usage: access-token.sh <admin|user>}"
kc=https://localhost:8443/realms/libredb/protocol/openid-connect
redirect='org.libredb.mobile:/oauth2redirect'
jar=$(mktemp)
trap 'rm -f "$jar"' EXIT

verifier=$(head -c 48 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')
challenge=$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=\n')

page=$(curl -skf -c "$jar" -b "$jar" -G "$kc/auth" \
  --data-urlencode client_id=libredb-mobile --data-urlencode response_type=code --data-urlencode scope=openid \
  --data-urlencode "redirect_uri=$redirect" --data-urlencode state=recording \
  --data-urlencode code_challenge_method=S256 --data-urlencode "code_challenge=$challenge")
action=$(printf '%s' "$page" | { grep -o 'id="kc-form-login"[^>]*action="[^"]*"' || true; } |
  sed 's/.*action="//;s/"$//;s/&amp;/\&/g')
if [ -z "$action" ]; then
  echo "Keycloak's sign-in page has no login form (kc-form-login)" >&2
  exit 1
fi

location=$(curl -sk -c "$jar" -b "$jar" -o /dev/null -w '%{redirect_url}' "$action" \
  --data-urlencode "username=$user" --data-urlencode "password=$user" --data-urlencode credentialId=)
code=$(printf '%s' "$location" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')
if [ -z "$code" ]; then
  echo "Keycloak returned no code for $user" >&2
  exit 1
fi

curl -skf "$kc/token" --data-urlencode grant_type=authorization_code --data-urlencode client_id=libredb-mobile \
  --data-urlencode "code=$code" --data-urlencode "redirect_uri=$redirect" --data-urlencode "code_verifier=$verifier" |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"])'
