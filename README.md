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
- **SOS System** — One-tap emergency trigger that notifies all contacts with your live location
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
users/{uid}/
  assets/       — QR assets owned by user
  contacts/     — Emergency contacts
  alerts/       — Notifications feed

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
- Firebase project (Blaze plan for Firestore)

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
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /scan_events/{doc} {
      allow create: if true;
      allow read: if request.auth != null;
    }
    match /sos_events/{doc} {
      allow create, read: if request.auth != null;
    }
    match /incidents/{doc} {
      allow create, read: if request.auth != null;
    }
    match /live_locations/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

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
