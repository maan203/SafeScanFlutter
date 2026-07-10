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
- **Authentication** — Email/password and Google Sign-In via Firebase Auth
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
├── models/                 # UserModel, AssetModel, ContactModel, AlertModel
├── services/               # AuthService, AssetService, ContactService,
│                           # AlertService, LocationService, SosService
├── providers/              # AuthProvider, AssetsProvider,
│                           # ContactsProvider, AlertsProvider
└── screens/                # 17 screens — login to SOS
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

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /assets/{assetId} {
      // Anyone can read an asset by ID — this is how a stranger who scans
      // your QR code sees the "found this item" screen without an account.
      allow read: if true;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
      // Owner can change anything. Anyone else (a finder scanning the QR)
      // may only bump scanCount — nothing else — so recordScan() works
      // without letting a stranger edit the asset's details.
      allow update: if (request.auth != null && request.auth.uid == resource.data.userId)
        || request.resource.data.diff(resource.data).affectedKeys().hasOnly(['scanCount']);
    }
    match /users/{uid}/alerts/{alertId} {
      allow read, update: if request.auth != null && request.auth.uid == uid;
      // Must allow an unauthenticated finder to notify the owner, but only
      // for a scan or incident alert tied to an asset that really belongs
      // to this uid — never an arbitrary alert for someone else.
      allow create: if (request.resource.data.type == 'scan' || request.resource.data.type == 'incident' || request.resource.data.type == 'emergency')
        && get(/databases/$(database)/documents/assets/$(request.resource.data.assetId)).data.userId == uid;
    }
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /scan_events/{doc} {
      allow create: if true;
      allow read: if request.auth != null;
    }
    match /sos_events/{sosId} {
      // Only the person who triggered the SOS can read or update it —
      // not just "any logged-in user", which would leak GPS coordinates
      // and emergency contact phone numbers to every other account.
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      allow read, update: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    match /incidents/{incidentId} {
      // Same principle: only the reporter can read their own report back.
      allow create: if request.auth != null && request.auth.uid == request.resource.data.reportedBy;
      allow read: if request.auth != null && request.auth.uid == resource.data.reportedBy;
    }
    match /live_locations/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /chats/{chatId} {
      // Only the asset's owner and the finder who started the chat can see
      // or touch it. finderId can be a real account or an anonymous one.
      allow read, update: if request.auth != null
        && (request.auth.uid == resource.data.ownerId || request.auth.uid == resource.data.finderId);
      allow create: if request.auth != null && request.auth.uid == request.resource.data.finderId;
      // Only a resolved (closed) chat can be deleted, and only by one of
      // its two participants — an open conversation can't be yanked away.
      allow delete: if request.auth != null
        && (request.auth.uid == resource.data.ownerId || request.auth.uid == resource.data.finderId)
        && resource.data.isClosed == true;

      match /messages/{messageId} {
        allow read: if request.auth != null &&
          (request.auth.uid == get(/databases/$(database)/documents/chats/$(chatId)).data.ownerId ||
           request.auth.uid == get(/databases/$(database)/documents/chats/$(chatId)).data.finderId);
        allow create: if request.auth != null &&
          request.auth.uid == request.resource.data.senderId &&
          get(/databases/$(database)/documents/chats/$(chatId)).data.isClosed == false &&
          (request.auth.uid == get(/databases/$(database)/documents/chats/$(chatId)).data.ownerId ||
           request.auth.uid == get(/databases/$(database)/documents/chats/$(chatId)).data.finderId);
      }
    }
  }
}
```

> **You must paste this into Firebase Console → Firestore Database → Rules yourself** — this repo doesn't include a `firestore.rules` file wired to auto-deploy, so I can't apply it for you.

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

---

## License

This project is for personal and educational use.
