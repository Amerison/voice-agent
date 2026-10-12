#!/usr/bin/env bash
# Runs the app with VAPI_PUBLIC_KEY, and API_BASE_URL when set, from .env.
# Only those two are read so VAPI_PRIVATE_KEY and the Twilio credentials never
# reach the app binary. Without API_BASE_URL the app runs in demo mode. Extra
# arguments pass through to `flutter run`, e.g. `tool/run.sh -d <device-id>`.
set -euo pipefail
cd "$(dirname "$0")/.."

env_value() {
  sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$1=//p" .env 2>/dev/null |
    tail -n 1 | sed -E "s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]*$//"
}

key=$(env_value VAPI_PUBLIC_KEY)
if [[ -z "$key" ]]; then
  echo "VAPI_PUBLIC_KEY is missing from .env" >&2
  exit 1
fi
defines=(--dart-define=VAPI_PUBLIC_KEY="$key")
api=$(env_value API_BASE_URL)
if [[ -n "$api" ]]; then
  defines+=(--dart-define=API_BASE_URL="$api")
else
  echo "API_BASE_URL isn't set in .env, so the app runs in demo mode." >&2
fi

exec flutter run "${defines[@]}" "$@"
