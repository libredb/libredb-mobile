#!/usr/bin/env bash
# Checks the release's version before anything is built: the tag must name the version of pubspec.yaml, and the build
# number behind the `+` must be above every build number a released tag carries (docs/release.md).
# Play's version code is that build number (android/app/build.gradle.kts: `versionCode = flutter.versionCode`), and
# Play refuses a bundle whose version code it already holds. Without this check that refusal arrives only at the
# upload, after the suite has run, the upload key has signed the bundle and Sentry already holds the release, which is
# how the v1.1.2 release died. It reads pubspec.yaml and the tags of the working directory and asks Play nothing: the
# Play service account lives in the play-internal environment, which the verify job does not deploy to.
# Run it from the repository root of a checkout with every tag (fetch-depth: 0).
# Usage: RELEASE_TAG=v1.2.3 tool/release/check_release_version.sh
# An empty RELEASE_TAG is a dry run from a branch: it only says what a release of this version would run into.
# Exit 1 refuses the release, exit 2 means the script was run in the wrong place.
set -euo pipefail

tag=${RELEASE_TAG:-}

if [ ! -f pubspec.yaml ]; then
  echo "No pubspec.yaml in $(pwd); run this script from the repository root."
  exit 2
fi
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "$(pwd) is no git repository; the check reads the released build numbers from the v*.*.* tags."
  exit 2
fi

version=$(sed -n 's/^version: *\([^ ]*\).*$/\1/p' pubspec.yaml | head -n 1)
if [ -z "$version" ]; then
  echo "pubspec.yaml names no version."
  exit 1
fi
name=${version%%+*}
code=${version#*+}
if [ "$code" = "$version" ] || ! printf '%s' "$code" | grep -Eq '^[0-9]+$'; then
  echo "pubspec.yaml names version '$version', which carries no +<build number>. Play's version code is that build" \
    "number, so a release needs one, such as $name+1."
  exit 1
fi

if [ -n "$tag" ] && [ "$tag" != "v$name" ]; then
  echo "The tag $tag does not match version $name in pubspec.yaml."
  exit 1
fi

# The highest build number any other v*.*.* tag released is the highest version code Play was given.
highest=0
highest_tag=
while IFS= read -r released_tag; do
  if [ -z "$released_tag" ] || [ "$released_tag" = "$tag" ]; then
    continue
  fi
  released=$(git show "$released_tag:pubspec.yaml" 2> /dev/null |
    sed -n 's/^version: *[^+ ]*+\([0-9][0-9]*\).*$/\1/p' | head -n 1)
  if [ -z "$released" ]; then
    continue
  fi
  if [ "$released" -gt "$highest" ]; then
    highest=$released
    highest_tag=$released_tag
  fi
done <<EOF
$(git tag --list 'v*.*.*')
EOF

if [ -z "$tag" ]; then
  echo "Dry run of version $version: no tag to check."
  if [ -n "$highest_tag" ] && [ "$code" -le "$highest" ]; then
    echo "Note: build number $code is not above $highest, the one $highest_tag released. Released as it is, Play" \
      "would refuse the bundle for its version code."
  fi
  exit 0
fi

if [ -z "$highest_tag" ]; then
  echo "Version $version: no other v*.*.* tag carries a build number, so there is no released version code to" \
    "compare with. If this is not the first release, the checkout fetched no tags (fetch-depth: 0)."
  exit 0
fi

if [ "$code" -le "$highest" ]; then
  echo "The build number of $version is $code, and $highest_tag already released $highest. Play refuses a bundle" \
    "whose version code it holds (\"Version code has already been used\"), so this release would fail at the upload," \
    "after the bundle was signed. Raise the version in pubspec.yaml above $highest and tag the new commit."
  exit 1
fi

echo "Version $version: the tag matches, and build number $code is above $highest, the one $highest_tag released."
