#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

OUT_DIR="${TMPDIR:-/tmp}/jianshengjily-workout-service"
mkdir -p "$OUT_DIR"

swiftc \
  jianshengjily/Models/Exercise.swift \
  jianshengjily/Models/SetLog.swift \
  jianshengjily/Models/TrainingPlan.swift \
  jianshengjily/Models/WorkoutSession.swift \
  jianshengjily/Models/WorkoutTemplate.swift \
  jianshengjily/Services/Localization.swift \
  jianshengjily/Services/DefaultContentLocalization.swift \
  jianshengjily/Services/WorkoutLogic.swift \
  jianshengjily/Services/WorkoutService.swift \
  scripts/check_workout_service.swift \
  -o "$OUT_DIR/check_workout_service"

"$OUT_DIR/check_workout_service"
