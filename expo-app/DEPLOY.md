# Deploying to the Apple App Store

## Prerequisites

1. **Expo Account** — Create one at https://expo.dev
2. **Apple Developer Account** — Required for App Store submission ($99/year)
3. **Node.js 18+** installed
4. **EAS CLI** installed: `npm install -g eas-cli`

---

## One-time Setup

### 1. Install dependencies
```bash
cd expo-app
npm install
```

### 2. Log in to Expo
```bash
eas login
```

### 3. Initialize EAS for this project
```bash
eas init
```
This generates an `extra.eas.projectId` in `app.json`. Copy it in.

### 4. Update `eas.json` with your Apple info
```json
"submit": {
  "production": {
    "ios": {
      "appleId": "you@email.com",
      "ascAppId": "1234567890",      ← from App Store Connect
      "appleTeamId": "ABCDEF1234"    ← from developer.apple.com
    }
  }
}
```

---

## Build for the App Store

EAS handles provisioning profiles and signing automatically.

```bash
# Production build (uploaded to Apple)
eas build --platform ios --profile production
```

This takes ~10–15 minutes. EAS will ask to create certificates/profiles on first run.

---

## Submit to App Store

After the build completes:

```bash
eas submit --platform ios --profile production
```

This uploads the IPA to App Store Connect. Then go to
https://appstoreconnect.apple.com to complete the submission (screenshots,
description, pricing, etc.).

---

## Development / Testing

```bash
# Run on iOS Simulator
eas build --platform ios --profile development
# or
npx expo start --ios

# Internal distribution (TestFlight-style)
eas build --platform ios --profile preview
```

---

## App Details

| Field | Value |
|-------|-------|
| Bundle ID | `toraschaim.ytcalumni1` |
| App Name | YTC Alumni |
| Firebase Project | `toras-chaim-shiurim` |
