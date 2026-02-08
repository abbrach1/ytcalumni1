# YTC Alumni - Android App

Android version of the Yeshiva Toras Chaim Alumni Network app, built with Kotlin and Jetpack Compose.

## Tech Stack

- **Language**: Kotlin
- **UI**: Jetpack Compose + Material 3
- **Backend**: Firebase (Auth, Firestore, Cloud Messaging)
- **Audio**: Media3 / ExoPlayer
- **DI**: Hilt
- **Image Loading**: Coil
- **Architecture**: MVVM with StateFlow

## Setup

1. **Firebase Configuration**
   - Create an Android app in your Firebase Console with package name `com.ytcalumni.app`
   - Download `google-services.json` and place it in `android-app/app/`
   - Ensure Firestore, Authentication (Email/Password), and Cloud Messaging are enabled

2. **Build**
   - Open the `android-app` folder in Android Studio
   - Sync Gradle files
   - Build and run on a device or emulator (API 26+)

## Project Structure

```
app/src/main/java/com/ytcalumni/app/
├── YTCAlumniApp.kt          # Application class
├── MainActivity.kt           # Entry point
├── di/                       # Dependency injection
├── models/                   # Data models
├── services/                 # Firebase service layer
├── managers/                 # Auth, Audio, Notification managers
└── ui/
    ├── theme/                # Colors, Typography, Theme
    ├── navigation/           # Bottom nav + routing
    ├── components/           # Reusable UI components
    ├── auth/                 # Login & Request Access
    ├── home/                 # Home dashboard
    ├── shiurim/              # Shiurim library + audio player
    ├── events/               # Events / Simchos
    └── contacts/             # Alumni & Rebbeim directory
```

## Features

- Firebase Auth with email/password + approval system
- Home feed with carousel, announcements, featured shiurim, alumni spotlight
- Full shiurim library with search, filters (rebbe, topic, series), sort, bookmarks
- Audio player with ExoPlayer: play/pause, skip, speed control, volume, progress sync
- Mini player overlay + full-screen player dialog
- Cross-device playback position syncing via Firebase
- Events/Simchos calendar with submission form
- Alumni directory with expandable contact cards
- Contact info submission and editing
- Push notifications via Firebase Cloud Messaging
- Material 3 design matching the iOS color scheme (Navy, Gold, Cream)

## Firebase Collections Used

Same as the iOS app - fully compatible with the shared Firebase backend:
- `shiurim`, `events`, `announcements`, `carouselImages`, `alumniPhotos`
- `rebbeim`, `alumniDatabase`, `approvedEmails`, `admins`
- `alumniContactSubmissions`, `simchaSubmissions`, `shiurCollections`
- `settings/featuredShiur`
- `users/{uid}/preferences/` (playback positions, saved shiurim)
