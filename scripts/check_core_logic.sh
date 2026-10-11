#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

OUT_DIR="${TMPDIR:-/tmp}/jianshengjily-core-logic"
mkdir -p "$OUT_DIR"

swiftc \
  jianshengjily/Services/Localization.swift \
  jianshengjily/Services/WorkoutLogic.swift \
  scripts/check_core_logic.swift \
  -o "$OUT_DIR/check_core_logic"

"$OUT_DIR/check_core_logic"
