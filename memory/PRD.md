# Flayr - Short Video App - PRD

## What's Been Implemented (April 15, 2026)

### Session 1 - SHA-1 & Keystore
- Release keystore created, SHA-1 extracted

### Session 2 - GitHub Actions
- Fixed key.properties, consolidated workflows

### Session 3 - Chat & Notifications Fix
- Fixed null notification data, FCM token refresh, channel ID mismatch

### Session 4 - Auto Build & Release
- Updated `build-apk.yml` workflow:
  - Auto builds on every push to master/main
  - Creates GitHub Release with versioned tag (v1.0.0-buildXX)
  - Uploads APK as downloadable release asset
  - Also uploads as artifact (90 day retention)
  - Extracts SHA-1 in build summary
  - Shows version, commit, APK size in release notes

## Backlog
- P0: Verify auto build works after push
- P1: Test chat + notifications on devices
- P2: Add Firebase App Distribution
- P2: Add version bumping workflow
