# Customer Agent

An iOS-first Flutter app for configuring a lead-qualification voice agent, giving it its own Twilio phone number answered by Vapi, reviewing calls, and managing a lightweight CRM.

## What is implemented

- Guided onboarding for an AI receptionist or AI lead qualification agent: identity, voice, business type, website, calendar, greeting, a live test call, and number choice
- Identity, friendliness, persona, company, and greeting configuration
- Exact webpage URLs, short answers, guidelines, and action controls
- Vapi assistant sync, and a Twilio number per agent imported into Vapi, through a server-side API
- Vapi tools for creating contacts and booking against mock availability
- Duplicate-safe end-of-call webhook ingestion
- Call list, resolution result, completed actions, and transcript viewer
- Contact CRM with seeded demo data and full local CRUD
- Local demo mode when no API URL is supplied

## Security boundary

`VAPI_PRIVATE_KEY`, `TWILIO_ACCOUNT_SID`, and `TWILIO_AUTH_TOKEN` are used only by the Dart API in `server/`. Never pass them through `--dart-define` or add them to the Flutter app. The root `.env` file is gitignored and Conductor copies `.env` files into new workspaces by default.

## Where data lives

This is a prototype: the agent, CRM contacts, meetings, and calls are stored only on the iPhone (`SharedPreferences`). The server keeps no copy. Each request carries the workspace and gets it back updated. The server's file store holds only:

- each installation's Twilio number and its Vapi id, so a retry never buys a second number
- webhook routes and secrets
- contacts, meetings, and calls created during a call, until the app's next refresh saves them

Deleting the app deletes its data, and its Twilio number keeps billing until you release it in the Twilio Console. Installations are identified by a random bearer token. Before a public release, move to real auth and a database, and add rate limiting.

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
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=VAPI_PUBLIC_KEY="$VAPI_PUBLIC_KEY"
```

To run on a specific device, `tool/run.sh` reads only `VAPI_PUBLIC_KEY` and
`API_BASE_URL` from `.env` and passes any extra arguments to `flutter run`. A
phone can't reach `127.0.0.1` on your Mac, so set `API_BASE_URL` to the Mac's
LAN address (`ipconfig getifaddr en0`), for example `http://10.0.0.196:8080`:

```sh
tool/run.sh -d <device-id>
```

iOS builds started any other way (Xcode Run or Archive, an IDE Run button, or
plain `flutter run`) fill in those same two values from `.env` through
`tool/xcode_dart_defines.sh`, which the Xcode build phase loads. Values passed
with `--dart-define` take priority. `API_BASE_URL` is only read from `.env` for
Debug builds, so Release builds (including Xcode Archive and TestFlight) run in
demo mode. Release builds also ignore any `API_BASE_URL` that isn't `https://`,
so a home-network address can't ship to testers.

`VAPI_PUBLIC_KEY` is Vapi's client-safe public key and powers the in-app voice
test. Allow the synced assistant and enable transient assistants on that key so
unsynced drafts can be tested too. Keep `VAPI_PRIVATE_KEY` on the server only.

Run without `API_BASE_URL` to use local demo mode:

```sh
flutter run
```

The Conductor workspace exposes matching **server** and **ios** run scripts.

## Phone number

Onboarding shows a real, voice-capable local number that Twilio has free in the chosen area code (628, San Francisco's overlay, unless changed on the number step). **Finish setup** buys it on your Twilio account and imports it into Vapi with `provider: twilio`. Vapi then points the number's voice webhook at the agent's assistant and leaves its messaging settings alone. If the number was taken in the meantime, another in the same area code is bought. Busy area codes such as 415 and 212 sell out on Twilio; when that happens, the agent gets any available US local number instead. Deploy offers a retry if anything fails.

Setup:

1. Sign up at [twilio.com/try-twilio](https://www.twilio.com/try-twilio) and verify your email and phone.
2. Copy the Account SID and Auth Token from the Account info panel on [console.twilio.com](https://console.twilio.com) into `.env` as `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`, then restart the server.
3. Upgrade the account (Admin > Account billing) before real users onboard. Trial accounts hold one number, accept calls only from verified caller IDs, play a trial message before each call, cut calls at 10 minutes, and expire after 30 days. To test on a trial, buy its one number in the Console and set `TWILIO_PHONE_NUMBER` to it; every agent then shares that number.

A local US number costs about $1.15 a month plus per-minute voice charges, billed by Twilio. Vapi bills its own per-minute rate on top.

## Connect live Vapi webhooks

Without `PUBLIC_BASE_URL`, the server still syncs the assistant and pulls finished calls from Vapi's API (pull to refresh on Home or Calls; listing calls costs no credits). The contact and booking tools need webhooks, so Vapi must reach the API over public HTTPS. Set `PUBLIC_BASE_URL` to the deployed API URL or a development tunnel to enable them:

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

1. Deploy the server to a persistent HTTPS host and set `VAPI_PRIVATE_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `PUBLIC_BASE_URL`, and `DATA_FILE`.
2. Archive as-is for a demo-mode build, or pass the production API URL to go live: `flutter build ipa --dart-define=API_BASE_URL=https://api.example.com`.
3. Confirm the iOS bundle ID and App Store Connect app record.
4. Archive and upload the build from Xcode.
5. Add internal testers and complete a resolved and unresolved call walkthrough.

File-backed persistence is suitable for a controlled internal beta on one server instance. Multi-instance hosting requires shared storage or a database.
