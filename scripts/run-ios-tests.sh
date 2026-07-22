#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

default_project_id="danielapp-dev"
if [[ -f "GoogleService-Info.plist" ]]; then
  plist_project_id="$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' GoogleService-Info.plist 2>/dev/null || true)"
  if [[ -n "$plist_project_id" ]]; then
    default_project_id="$plist_project_id"
  fi
fi

export USE_FIREBASE_EMULATOR="${USE_FIREBASE_EMULATOR:-1}"
export FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-127.0.0.1}"
export FIRESTORE_EMULATOR_PORT="${FIRESTORE_EMULATOR_PORT:-8080}"
export FIREBASE_AUTH_EMULATOR_PORT="${FIREBASE_AUTH_EMULATOR_PORT:-9099}"
export FIREBASE_STORAGE_EMULATOR_PORT="${FIREBASE_STORAGE_EMULATOR_PORT:-9199}"
export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
export FIREBASE_STORAGE_EMULATOR_HOST="${FIREBASE_STORAGE_EMULATOR_HOST:-127.0.0.1:9199}"
export GCLOUD_PROJECT="${GCLOUD_PROJECT:-$default_project_id}"
export RUN_FIREBASE_EMULATOR_TESTS="${RUN_FIREBASE_EMULATOR_TESTS:-1}"

xcodebuild test \
  -project DanielApp.xcodeproj \
  -scheme DanielApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' \
  USE_FIREBASE_EMULATOR=1 \
  FIREBASE_EMULATOR_HOST="$FIREBASE_EMULATOR_HOST" \
  FIRESTORE_EMULATOR_PORT="$FIRESTORE_EMULATOR_PORT" \
  FIREBASE_AUTH_EMULATOR_PORT="$FIREBASE_AUTH_EMULATOR_PORT" \
  FIREBASE_STORAGE_EMULATOR_PORT="$FIREBASE_STORAGE_EMULATOR_PORT" \
  RUN_FIREBASE_EMULATOR_TESTS="$RUN_FIREBASE_EMULATOR_TESTS"
