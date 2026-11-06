# FieldNote for iOS

Native SwiftUI iOS client for the FieldNote mobile API in `J:\SOURCE\FieldNote\docs\mobile-api-v1.md`.

The visual direction uses the supplied reference: deep indigo and violet surfaces, electric cyan highlights, subtle circuit traces, and bright floating cards.

## Open and run

Open `FieldNote.xcodeproj` in Xcode, select the `FieldNote` scheme, set a signing team, then run on an iOS 17 or newer simulator/device. The app uses `https://fn.drkflm.co.za/api/v1` by default.

## Included

- Email/password sign in and account creation
- Bearer-token storage in Keychain and one automatic refresh attempt after an expired-token response
- Today summary, recent journal, progress history, profile settings, and date-keyed measurement entry
- Client-side US Navy estimate matching the API formula
- Server error details displayed in the app

## Current scope

Photo capture/upload, APNs registration, AI insight generation, account recovery, and offline write synchronization are not included yet. The API contract documents these features and the server-side prerequisites. Entry history is cached in memory for presentation only; the service remains authoritative.
