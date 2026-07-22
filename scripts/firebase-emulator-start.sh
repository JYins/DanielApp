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

export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
export FIREBASE_STORAGE_EMULATOR_HOST="${FIREBASE_STORAGE_EMULATOR_HOST:-127.0.0.1:9199}"
export GCLOUD_PROJECT="${GCLOUD_PROJECT:-$default_project_id}"

exec firebase emulators:start --only firestore,auth,storage --project "$GCLOUD_PROJECT"
