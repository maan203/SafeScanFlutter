# SafeScan

A Flutter app for QR-based asset safety management. Attach a QR code to your vehicle or asset — anyone who scans it can report incidents, and you get notified instantly.

## Features

- QR code generation for assets (vehicles, bikes, etc.)
- Incident reporting with photo evidence and GPS location
- Emergency contacts with one-tap calling
- SOS alert system
- Real-time alerts and notifications
- Firebase Authentication (email/password + Google Sign-In)

## Tech Stack

- Flutter + Dart
- Firebase Auth, Firestore, FCM
- Provider (state management)
- GoRouter (navigation)
- Geolocator + Geocoding (GPS)
- MobileScanner (QR scanning)

## Setup

1. Clone the repo
2. Run `flutter pub get`
3. Add your own `android/app/google-services.json` from Firebase Console
4. Run `flutter run`
