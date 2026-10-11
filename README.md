# Voice Agent

An iOS-first Flutter app for configuring a lead-qualification voice agent, provisioning an inbound Vapi number, reviewing calls, and managing a lightweight CRM.

## What is implemented

- Lead-qualification onboarding with future agent types shown as unavailable
- Identity, friendliness, persona, company, and greeting configuration
- Exact webpage URLs, short answers, guidelines, and action controls
- Vapi assistant sync and inbound number provisioning through a server-side API
- Vapi tools for creating contacts and booking against mock availability
- Duplicate-safe end-of-call webhook ingestion
- Call list, resolution result, completed actions, and transcript viewer
- Contact CRM with seeded demo data and full local CRUD
- Local demo mode when no API URL is supplied

## Security boundary

`VAPI_PRIVATE_KEY` is used only by the Dart API in `server/`. Never pass it through `--dart-define` or add it to the Flutter app. The root `.env` file is gitignored and Conductor copies `.env` files into new workspaces by default.

The current API uses a random per-installation bearer token and file-backed storage for the private TestFlight milestone. Before a public release, move persistence and identity to a managed database/auth service and add rate limiting.

## Run locally

Copy `.env.example` to `.env` and add the Vapi keys. The supplied workspace already has a gitignored `.env`.

Start the server:

```sh
set -a
source .env
set +a
export PORT=8080
cd server
dart pub get
dart run bin/server.dart
```

In another terminal, start the iOS app against it:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Run without `API_BASE_URL` to use local demo mode:

```sh
flutter run
```

The Conductor workspace exposes matching **server** and **ios** run scripts.

## Connect live Vapi webhooks

Vapi must reach the API over public HTTPS. Set `PUBLIC_BASE_URL` to the deployed API URL or a development tunnel before syncing an assistant:

```sh
PUBLIC_BASE_URL=https://api.example.com
```

The API creates a unique, authenticated webhook route for each agent. Calls are limited to ten minutes, recordings are disabled, and transcripts are enabled.

## Test

```sh
flutter analyze
flutter test
(cd server && dart analyze && dart test)
```

## TestFlight checklist

1. Deploy the server to a persistent HTTPS host and set `VAPI_PRIVATE_KEY`, `PUBLIC_BASE_URL`, and `DATA_FILE`.
2. Build Flutter with the production API URL: `--dart-define=API_BASE_URL=https://api.example.com`.
3. Confirm the iOS bundle ID and App Store Connect app record.
4. Archive and upload the build from Xcode.
5. Add internal testers and complete a resolved and unresolved call walkthrough.

File-backed persistence is suitable for a controlled internal beta on one server instance. Multi-instance hosting requires shared storage or a database.
