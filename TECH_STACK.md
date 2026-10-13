# Technology Stack

Customer Agent is a phone app for small businesses. The owner sets up an AI voice agent, gives it a phone number, and reviews the calls it answers. The agent books meetings, saves callers as contacts, and judges whether a lead is a good fit.

The project has two parts: a mobile app written in Flutter, and a small server written in Dart that runs on Fly.io. The server talks to three outside services: Vapi for the voice agent, Twilio for phone numbers, and Google Calendar for bookings.

| Tool | Role | Why |
| --- | --- | --- |
| Flutter | iOS and Android app | One codebase for both stores |
| Dart server | API and private keys | Keeps keys off the phone; same language as the app |
| Fly.io | Hosts the server | Always on, HTTPS, one-command deploys |
| Vapi | Runs voice calls | Speech, AI, and voices in one service |
| Twilio | Phone numbers | Standard for programmable numbers; works with Vapi |
| Google Calendar | Meeting bookings | Where owners already keep their schedule |

## Flutter: one app for iOS and Android

**What it is.** Flutter is Google's toolkit for building mobile apps from one codebase. You write the app once in the Dart language, and Flutter builds a native app for each platform.

**What I use it for.** Every screen in the app is Flutter: onboarding, the home dashboard, call details, the CRM, and settings. The app also stores the owner's data on the phone and runs live voice tests with the agent through Vapi's Flutter package.

**Why it makes sense.**

- **One codebase, two stores.** I write each feature once instead of twice in Swift and Kotlin. The same screens ship on iOS and Android, and they look the same on both.
- **Android is a small step.** The project targets iOS today. Adding Android means running `flutter create --platforms=android .` and testing on a device, not rewriting the app.
- **Fast iteration.** Hot reload shows a change on the phone in about a second, without losing the screen I'm on.
- **Built-in tests.** Flutter's widget tests tap through real screens, such as the full onboarding flow, without a phone or simulator.

## Dart server: the keeper of secrets

**What it is.** A small web server written in Dart, the same language as the app, using the `shelf` package.

**What I use it for.** The server holds every private key: Vapi, Twilio, and Google. The app never sees them. When the owner changes the agent, the app sends the change to the server, and the server updates Vapi. During a call, Vapi calls the server when the agent wants to book a meeting or save a contact.

**Why it makes sense.**

- **Keys stay off the phone.** Anyone can unpack an app and read what is inside. A key in the app is a public key.
- **One language.** The app and the server share Dart, so moving between them doesn't mean changing languages.
- **Small and fast.** The server compiles to a single program that starts in milliseconds and runs in 256 MB of memory.

## Fly.io: hosting the server

**What it is.** Fly.io runs apps in lightweight virtual machines close to users. You describe the app in one file, `fly.toml`, and deploy with one command, `fly deploy`.

**What I use it for.** Fly.io hosts the server at `voice-agent-glazia.fly.dev` in San Jose. A Fly volume stores the server's one data file, so it survives deploys. Fly also holds the private keys as encrypted secrets.

**Why it makes sense.**

- **Always on.** Vapi calls the server in the middle of a live phone call. If the server is asleep, the caller waits. Fly keeps one machine running at all times, which costs a few dollars a month.
- **Simple deploys.** Fly builds the server from its Dockerfile and swaps in the new version. There are no servers to patch.
- **HTTPS included.** Fly provides the certificate. Vapi, Twilio, and Google all need an HTTPS address to send requests back.
- **Room to grow.** More machines or regions take one setting change.

## Vapi: the voice agent

Vapi runs the conversation: speech-to-text, the language model (OpenAI's GPT-4o mini), and text-to-speech. The server builds the agent's instructions from the owner's settings and sends them to Vapi as an "assistant." After each call, Vapi sends a transcript and an analysis of whether the caller's goal was met and whether the lead qualifies.

Building this myself would mean joining three separate services and tuning how fast the agent replies and when it lets a caller interrupt. Vapi handles that, so I can spend my time on the business logic.

## Twilio: phone numbers

Twilio sells the phone number each agent answers. The server buys a local number in the area code the owner picks, then hands it to Vapi, which answers it. Twilio is the standard choice for programmable phone numbers, and Vapi connects to it directly.

## Google Calendar: real bookings

The owner connects their Google account once. During a call, the server checks the owner's free/busy times, offers only open slots, and adds the booked meeting to their calendar. Google's sign-in gives the server a long-lived token, so bookings keep working without the owner signing in again.

## Where data lives

The app keeps the agent's settings, contacts, meetings, and calls on the phone. The server keeps only what it needs: phone numbers it bought, calendar tokens, and records from calls that the app hasn't collected yet. This keeps the server small and avoids running a database while the product is a prototype. Before a public launch, the data moves to a real database with user accounts.
