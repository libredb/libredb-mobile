#!/bin/bash
set -e

#dart pub global activate fvm
#export PATH="$PATH":"$HOME/.pub-cache/bin"
fvm use 3.47.8

fvm flutter clean
fvm flutter pub get

scripts/generate_l10n.sh

# when flutter analyze issue found then exit
if ! fvm dart analyze; then
  echo "Flutter analyze found issues. Exiting."
  exit 1
fi

if ! fvm flutter test --coverage; then
  echo "Flutter test found issues. Exiting."
  exit 1
fi