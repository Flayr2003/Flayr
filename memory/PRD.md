# Flayr - Short Video App

## Original Problem Statement
User needs SHA-1 certificate fingerprint from APK signing certificate for Firebase Google Sign-In configuration.

## Architecture
- Flutter mobile app
- Firebase backend (Auth, Firestore, Messaging)
- Google Sign-In, Apple Sign-In
- Google Maps, Google Ads integration

## What's Been Implemented (April 15, 2026)
- Created release keystore (`android/app/flayr-release-key.jks`)
- Created `key.properties` for Gradle signing config
- Extracted SHA-1: `40:FB:94:73:AB:32:40:E3:1E:94:5B:3D:16:C0:21:41:B7:E6:50:20`
- Extracted SHA-256: `91:6F:03:2B:E8:89:F4:3D:58:0A:49:93:13:3B:82:5C:F0:59:A7:6A:56:06:8C:7F:0C:51:A6:13:6B:3D:34:2F`

## Keystore Details
- Path: `android/app/flayr-release-key.jks`
- Alias: `flayr-key`
- Password: `flayr2024release`
- Validity: 10,000 days

## Backlog
- P0: Add SHA-1 to Firebase Console
- P1: Build and test release APK locally
- P2: Add debug keystore SHA-1 to Firebase for dev testing
- P2: Test Google Sign-In end-to-end
