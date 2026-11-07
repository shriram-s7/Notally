# Notally

A secure, offline, encrypted notebook for Android (built with Flutter). Notes never leave the device unless you export an encrypted backup yourself.

## Features

- **Master-password lock** with first-run setup; the password is stretched with **Argon2id**. Biometric unlock is supported through the platform (`local_auth`).
- **Encrypted local database**: notes are stored in SQLite encrypted with SQLCipher (`sqlcipher_flutter_libs`) using Drift as the data layer.
- **Rich-text notes** with the Flutter Quill editor; note list and edit screens.
- **Encrypted backup and restore**: export a backup file protected with Argon2id + AES-256-GCM, share or email it, and restore it later with the backup password (the app verifies it before restoring).
- **Change master password** from Settings.
- Secrets (key material) are kept in the platform secure storage (`flutter_secure_storage`).

## Stack

Flutter / Dart, Riverpod (state), go_router (navigation), Drift + SQLCipher (storage), `cryptography` (Argon2id, AES-GCM), `flutter_secure_storage`, `local_auth`, `flutter_quill`, `share_plus`, `file_picker`.

## Run it

Requires the Flutter SDK (Dart 3.12+) and an Android device or emulator.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerates Drift code if needed
flutter run
```

Run the tests with `flutter test`.

## Structure

```
lib/
  main.dart
  core/                 app widget, router, theme, startup and security utilities
  features/
    auth/               lock and setup screens, Argon2id crypto service, secure storage
    notes/              Drift database, repository, list and edit screens
    settings/           change password, encrypted backup and restore
```

## Security notes

- There is no cloud sync and no account; losing the master password means the notes cannot be recovered.
- Do not commit `android/key.properties`, keystores or `local.properties`; they are git-ignored.
