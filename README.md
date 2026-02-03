# Science Galaxy Kids App

Science Galaxy turns learning into a space adventure with 101 science levels, animated galaxies, and playful missions designed for early explorers.

## Project Overview

The app wraps core science concepts in a gamified journey that stretches from level 0 launch prep to level 100 cosmic command. Players glide through themed worlds, unlock missions, earn badges, and track streaks inside a vibrant, touch-friendly interface.

## Feature Highlights

- Galaxy map with 101 progressive levels and themed learning worlds
- Mission decks featuring story-driven science challenges
- Profile hub with XP tracker, collectible badges, and streak heatmap
- Bold gradient-driven visuals tuned for kids and tablets
- Works on Android, iOS, web, Windows, macOS, and Linux from a single codebase

## Prerequisites

Make sure these tools are ready before you run the app:

- Flutter SDK 3.22.0 or newer
- Android Studio or VS Code with Flutter tooling
- Xcode (macOS) for iOS builds
- Chrome or Edge for web preview

## Installation and Setup

Install dependencies:

```bash
flutter pub get
```

Verify the toolchain:

```bash
flutter doctor
```

## Running the App

Choose your favorite device or platform:

```bash
flutter run -d chrome      # Web (Chrome)
flutter run -d edge        # Web (Edge)
flutter run -d windows     # Windows desktop
flutter run -d android     # Android device or emulator
flutter run -d ios         # iOS simulator (macOS only)
```

## Gameplay Guide

- Galaxy tab: swipe through the orbital level path, inspect progression, and jump between worlds.
- Missions tab: pick bite-sized science quests with instant XP rewards.
- Profile tab: review streaks, badges, and current level title before launching the next mission.

## Project Structure

```text
kids_app/
   lib/
      main.dart        # Science Galaxy entry point and UI composition
   test/
      widget_test.dart # Sample widget test
   pubspec.yaml       # Dependencies and assets
```

## Helpful Commands

```bash
flutter clean          # Reset build artifacts
flutter test           # Run widget and unit tests
flutter build apk      # Production Android build
flutter build web      # Production web build
```

## Contributing

1. Create a feature branch.
2. Implement and test your changes.
3. Submit a pull request that explains the feature, UI impact, and test coverage.

## License

This project ships under the MIT License.

---

Fuel curious minds. Reach for the stars.
