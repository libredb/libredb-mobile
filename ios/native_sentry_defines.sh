#!/bin/sh
# Writes the Sentry dart-defines of a lib/main/main_prod.dart build into the Info.plist of the built app, which
# NativeSentry.swift reads when it starts sentry-cocoa. It is the iOS half of the gate
# android/app/build.gradle.kts holds for the Android host: only the entry point that selects the prod environment,
# the only one in which the Dart side starts Sentry, gets a DSN, so no other build starts a native SDK whose Dart
# side never starts (lib/infrastructure/analytics/native_sentry_start.dart, nativeSdkReady).
#
# Xcode runs it as the last build phase of the Runner target, after the Info.plist is in place.
# test/architecture/sentry_native_scrub_patterns_test.dart fails when the gate stops naming that entry point or when
# a key is written before it.
set -eu

plist="${TARGET_BUILD_DIR:?}/${INFOPLIST_PATH:?}"

# Whatever an earlier build of another entry point left in the built Info.plist goes first.
for key in SENTRY_DSN SENTRY_ENVIRONMENT SENTRY_DIST; do
  /usr/libexec/PlistBuddy -c "Delete :${key}" "${plist}" >/dev/null 2>&1 || true
done

case "${FLUTTER_TARGET:-}" in
  */main_prod.dart) ;;
  *) exit 0 ;;
esac

# Flutter passes the dart-defines of the build as a comma separated list of base64 "KEY=VALUE" pairs.
for encoded in $(printf '%s' "${DART_DEFINES:-}" | tr ',' ' '); do
  define=$(printf '%s' "${encoded}" | base64 --decode 2>/dev/null) || continue
  key=${define%%=*}
  value=${define#*=}
  [ -n "${value}" ] || continue
  case "${key}" in
    SENTRY_DSN | SENTRY_ENVIRONMENT | SENTRY_DIST)
      /usr/libexec/PlistBuddy -c "Add :${key} string ${value}" "${plist}"
      ;;
  esac
done
