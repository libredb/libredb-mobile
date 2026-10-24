#!/usr/bin/env bash
# Decides whether the release build uploads its Dart symbols and R8 mapping to Sentry (docs/release.md), and writes
# upload=true or upload=false to $GITHUB_OUTPUT. A release needs the SENTRY_AUTH_TOKEN secret of the release-signing
# environment and fails without it; a dry run never uploads, with or without the token.
# Usage: RELEASE_KIND=release|dry-run SENTRY_AUTH_TOKEN=<token or empty> GITHUB_OUTPUT=<file> \
#   tool/release/check_sentry_upload.sh
set -euo pipefail

if [ -z "${GITHUB_OUTPUT:-}" ]; then
  echo "GITHUB_OUTPUT is not set; run this script as a step of the release workflow."
  exit 2
fi

case "${RELEASE_KIND:-}" in
  dry-run)
    echo "Dry run: the Dart symbols and the R8 mapping are not uploaded to Sentry; a dry run never reaches Sentry."
    echo "upload=false" >> "$GITHUB_OUTPUT"
    ;;
  release)
    if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
      echo "The secret SENTRY_AUTH_TOKEN of the release-signing environment is not set, so the Dart symbols and the" \
        "R8 mapping of this release cannot be uploaded to Sentry (docs/release.md)."
      exit 1
    fi
    echo "The Dart symbols and the R8 mapping will be uploaded to Sentry after the build."
    echo "upload=true" >> "$GITHUB_OUTPUT"
    ;;
  *)
    echo "RELEASE_KIND must be release or dry-run, but it is '${RELEASE_KIND:-}'."
    exit 2
    ;;
esac
