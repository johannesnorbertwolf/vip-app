# VIP app (unofficial prototype)

An iPhone app prototype for members of VIP, the study association for Psychology students in Groningen. It shows the content of [vipsite.nl](https://www.vipsite.nl) in a native app: events, photos, the member directory and your own profile.

> **Unofficial.** This is a student prototype, not made or endorsed by the VIP board or by Congressus. It is meant to explore what a VIP app could look like. If it is ever released, the VIP board will own it.

## Features

- **Events:** upcoming events as a list, calendar or poster gallery; event details; sign-up through the website's own checkout; subscribe your calendar to your events.
- **Photos:** the members' photo archive by year, month and album, with a full-screen viewer that can share and save photos.
- **Members:** search the member directory ("Stalking Guide") and open a member's page. Shows only what each member chose to share.
- **Me:** your profile, a digital membership card for partner discounts, upcoming events, past events and orders, committees, invoices and membership options.
- **More:** first-year student guide, loyalty points with a QR scanner, trust persons, complaints procedure, contact, and settings.

## How it works

VIP's website runs on [Congressus](https://www.congressus.nl). This prototype has no API access, so it reads the website's pages the way a browser does:

- You log in with your own vipsite.nl account. Your password is sent only to vipsite.nl and is **never stored**; the site's "stay logged in" cookie keeps you signed in.
- The app only **reads** pages. Anything that changes data (event sign-up and payment, profile edits, preferences) opens the real website inside the app.
- There is no server. Nothing about you or other members leaves your phone, and member search results are not cached.

All website access lives in two files, [`Sources/VIPClient.swift`](Sources/VIPClient.swift) and [`Sources/Scraper.swift`](Sources/Scraper.swift). An official version should replace them with the Congressus API and Congressus login.

Because it reads HTML, the app breaks when the website's layout changes.

## Build and run

Requirements: a Mac with Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone <this repo>
cd vip-app
xcodegen generate
open VIPApp.xcodeproj
```

Pick an iPhone simulator and press Run.

To run on your own iPhone, set your Apple developer team ID before generating the project (Xcode → Settings → Accounts shows it; a free Personal Team works):

```bash
DEVELOPMENT_TEAM=YOURTEAMID xcodegen generate
```

With a free Apple account the app stops opening after 7 days and has to be reinstalled.

## Project layout

| File | What it does |
|---|---|
| `Sources/VIPClient.swift` | Session with vipsite.nl: login, logout, fetching pages |
| `Sources/Scraper.swift` | Turns website pages into app data |
| `Sources/*Views.swift` | The screens |
| `IDEAS.md` | Feedback and ideas for later versions |
| `project.yml` | XcodeGen project definition |

## Licence

MIT. See [LICENSE](LICENSE).
