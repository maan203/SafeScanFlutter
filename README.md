# SafeScan

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white"/>
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>
</p>

<p align="center">
  <a href="https://drive.google.com/uc?export=download&id=1U-b8IIQby2FNV5m6DOFxZIEGTjXWnTa3">
    <img src="https://img.shields.io/badge/Download%20APK-Latest%20Release-22C55E?style=for-the-badge&logo=android&logoColor=white"/>
  </a>
</p>

<p align="center">
  A QR-based asset safety platform built with Flutter and Firebase. Attach a QR code to any asset — vehicle, bike, or equipment — and enable instant incident reporting, emergency alerts, and real-time notifications.
</p>

---

## Features

- **QR Code Management** — Generate unique QR codes for assets, toggle active/inactive, track scan history
- **Incident Reporting** — Report accidents, damage, or wrong parking with photo evidence and auto-detected GPS location
- **Emergency Contacts** — Add contacts that are alerted instantly during an SOS event
- **SOS System** — Hold-to-trigger emergency button that opens your messaging app with your live location pre-filled, ready to send to all emergency contacts in one tap
- **Real-time Alerts** — Firebase-powered push notifications and in-app alert feed
- **In-App Chat** — A finder who scans a QR code can message the owner directly (photos, shared location) without exchanging phone numbers, signing in anonymously if they don't have an account
- **Authentication** — Email/password, Google Sign-In, and anonymous guest sign-in via Firebase Auth
- **QR Scanner** — Scan any SafeScan QR code using the device camera

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter (Dart) |
| State Management | Provider (ChangeNotifier) |
| Navigation | GoRouter |
| Backend | Firebase Firestore |
| Authentication | Firebase Auth + Google Sign-In |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Location | Geolocator + Geocoding |
| QR Scanning | MobileScanner |
| Image Picker | image_picker |
| Phone Calls | url_launcher |

---

## Project Structure

```
lib/
├── main.dart               # App entry, Firebase init, MultiProvider, GoRouter
├── models/                 # UserModel, AssetModel, ContactModel, AlertModel,
│                           # ChatModel, ChatMessageModel
├── services/               # AuthService, AssetService, ContactService,
│                           # AlertService, LocationService, SosService,
│                           # ChatService, NotificationService, SettingsService
├── providers/              # AuthProvider, AssetsProvider, ContactsProvider,
│                           # AlertsProvider, ChatsProvider
└── screens/                # 19 screens — onboarding to SOS and in-app chat
```

---

## Firestore Collections

```
assets/         — QR assets, keyed by asset ID (readable by anyone who scans
                  the QR — needed so a finder can look one up without an
                  account; writes restricted to the owner via userId)

users/{uid}/
  contacts/     — Emergency contacts
  alerts/       — Notifications feed

chats/{chatId}/
  messages/     — In-app conversation between an asset owner and a finder,
                  scoped to one asset; either side can close it once resolved

scan_events/    — Public QR scan log
sos_events/     — SOS triggers
incidents/      — Reported incidents
live_locations/ — Real-time location sharing
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Android Studio / VS Code
- Firebase project on the free **Spark** plan (Firestore, Auth, and Hosting are all free at this scale — no billing account needed)

### Installation

```bash
# Clone the repository
git clone https://github.com/maan203/SafeScanFlutter.git
cd SafeScanFlutter

# Install dependencies
flutter pub get
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password + Google)
3. Create a **Firestore** database
4. Download `google-services.json` and place it in `android/app/`
5. Add your debug SHA-1 fingerprint to Firebase for Google Sign-In:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

### Firestore Security Rules

Rules live in [`firestore.rules`](firestore.rules) and are wired into [`firebase.json`](firebase.json), so they deploy alongside Hosting instead of needing to be pasted into the console by hand:

```bash
firebase deploy --only firestore:rules
```

They enforce, per collection: `assets` are readable by anyone via `get` (needed for the "found this item" QR flow) but not listable outside the owner's own query, and only the owner can write to one — except an anonymous scan, which may bump `scanCount` by exactly 1 and nothing else; `users/{uid}` profiles, `contacts`, and `live_locations` are owner-only; `alerts` accepts validated scan/SOS/incident/emergency writes from anyone (a stranger scanning a QR usually isn't signed in) but only the owner can read or mark them read; `sos_events` and `incidents` are readable only by whoever created them; and `chats`/`messages` are restricted to the asset's owner and the finder who started the conversation, with `senderId` forced to match the caller's own auth uid and writes blocked once a chat is closed.

### Web Fallback (free, no app install required)

QR codes point to `https://safescan-cfe7e.web.app/found/{assetId}` — a static page in [`web-fallback/`](web-fallback/index.html) that reads the public `assets/{id}` Firestore document directly via the Firebase JS SDK. Anyone who scans the QR with a plain camera app (no SafeScan installed) sees the asset's name, reward message, and a call-owner button, plus a "Get the SafeScan App" link for the full chat/emergency-relay experience. It also records the scan the same way the in-app flow does. Entirely on Firebase's free **Spark** plan — Hosting doesn't require Cloud Functions or a billing account.

Deploy it yourself (I don't have access to your Firebase project to do this for you):

```bash
npm install -g firebase-tools   # one-time
firebase login                  # one-time, opens a browser to sign in
firebase deploy --only hosting  # run from the project root, redeploy after any web-fallback/ edit
```

It'll deploy to `https://safescan-cfe7e.web.app` automatically (matches this project's ID). If the page shows a permission or API-key error, register a dedicated Web app in **Firebase Console → Project Settings → Your apps → Add app → Web** (free) and swap in that config inside `web-fallback/index.html`.

### Run

```bash
flutter run
```

---

## Android Permissions

| Permission | Purpose |
|---|---|
| `INTERNET` | Firebase + network calls |
| `ACCESS_FINE_LOCATION` | GPS for incidents and SOS |
| `CAMERA` | QR scanning and photo capture |
| `POST_NOTIFICATIONS` | Push notifications |
| `VIBRATE` | SOS haptic feedback |

---

## Notes

- `google-services.json` is excluded from version control — never commit Firebase config files
- `minSdk = 21` required for Firebase and Geolocator compatibility
- Google Sign-In requires the debug/release SHA-1 fingerprint registered in Firebase Console
- Release builds are signed via `android/key.properties` + a keystore (both excluded from version control, per [`android/.gitignore`](android/.gitignore)) — generate your own with `keytool -genkeypair` and see [`android/app/build.gradle.kts`](android/app/build.gradle.kts) for the expected `key.properties` format; without one, release builds fall back to the debug keystore and must not be distributed

---

## License

This project is for personal and educational use.
