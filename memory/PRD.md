# Flayr - Short Video App - PRD

## Original Problem Statement
User needs SHA-1 for Firebase Google Sign-In, build release APK via GitHub Actions, push to GitHub.

## What's Been Implemented (April 15, 2026)

### Session 1 - SHA-1 & Release Setup
- Created release keystore: `android/app/flayr-release-key.jks`
- SHA-1: `40:FB:94:73:AB:32:40:E3:1E:94:5B:3D:16:C0:21:41:B7:E6:50:20`

### Session 2 - GitHub Actions Fix
- Fixed `key.properties` storeFile path (was `app/flayr-release-key.jks`, now `flayr-release-key.jks`)
- Consolidated 4 workflows into 2 clean ones: `build-apk.yml` + `get-sha1.yml`
- Removed conflicting `main.yml` and `build-release.yml`
- Fixed `gradle.properties` memory settings (4GB for GitHub Actions)
- Updated `google-services.json` from Firebase

### Key Files
- `android/app/flayr-release-key.jks` - Release keystore
- `android/key.properties` - Signing config (password: flayr2024release, alias: flayr-key)
- `android/app/google-services.json` - Firebase config
- `.github/workflows/build-apk.yml` - Main build workflow
- `.github/workflows/get-sha1.yml` - SHA-1 extraction workflow

## Backlog
- P0: Verify GitHub Actions build succeeds after push
- P1: Test Google Sign-In on device
- P2: Add GitHub Release workflow
- P2: Add Firebase App Distribution step
