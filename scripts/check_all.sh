#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

echo "== Core logic =="
./scripts/check_core_logic.sh

echo
echo "== Workout service =="
./scripts/check_workout_service.sh

echo
echo "== Localizations =="
node ./scripts/check_localizations.mjs

echo
echo "== Exercise glyphs =="
node ./scripts/check_exercise_glyphs.mjs

echo
echo "== iOS build =="
./scripts/check_ios_build.sh

echo
echo "== Watch build =="
xcodebuild \
  -project jianshengjily.xcodeproj \
  -target 'jianshengjily Watch App' \
  -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

echo
echo "All checks passed."
