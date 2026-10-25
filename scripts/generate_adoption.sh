#!/usr/bin/env bash
set -euo pipefail

# Rewrites assets/adoption.json with the current adoption figures, which the onboarding shows. Run it when the
# figures should be refreshed, then commit the asset: the app reads it from the bundle and never fetches it.
#
# The figures come from libredb/libredb-adoption, which is PRIVATE, so this needs an authenticated gh. That is the
# whole reason the figures are baked in rather than fetched: a shipped app cannot read a private repository, and the
# alternative would be a credential in the binary.
#
# Usage: scripts/generate_adoption.sh            (uses fvm)
#        DART=dart scripts/generate_adoption.sh  (uses the dart on PATH, as CI would)

DART="${DART:-fvm dart}"
REPO="${ADOPTION_REPO:-libredb/libredb-adoption}"

cd "$(git rev-parse --show-toplevel)"

command -v gh >/dev/null || { echo "gh is not installed; it is needed to read the private $REPO" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not signed in; run 'gh login' — $REPO is private" >&2; exit 1; }

series_dir="$(mktemp -d)"
trap 'rm -rf "$series_dir"' EXIT

for name in engines channels listings; do
  gh api "repos/$REPO/contents/data/$name.jsonl" -q '.content' \
    | base64 -d > "$series_dir/$name.jsonl" \
    || { echo "could not read data/$name.jsonl from $REPO" >&2; exit 1; }
done

# The newest date any of the three series carries, so the asset records when the figures were true rather than when
# the script happened to run.
measured_on="$(cat "$series_dir"/*.jsonl | sed -n 's/.*"date":"\([0-9-]*\)".*/\1/p' | sort | tail -1)"
[ -n "$measured_on" ] || { echo "no measurement date in the series" >&2; exit 1; }

$DART run tool/adoption/generate.dart "$series_dir" assets/adoption.json "$measured_on"
