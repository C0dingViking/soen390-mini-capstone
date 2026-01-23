# Flutter Setup Guide (macOS)

This guide explains how to set up Flutter on **macOS** for development on this project.

Note: This guide assumes you are using **macOS 12 (Monterey) or later** and have administrator access.

## 1) Install Flutter SDK

Flutter’s official installation instructions should be followed, since they are kept up to date.

### Step 1: Follow the official Flutter install guide
Install Flutter by following the macOS instructions here:

https://docs.flutter.dev/install/quick

This includes:
- Downloading the Flutter SDK
- Extracting it to a local directory (example: `~/development/flutter`)
- Adding Flutter to your shell `PATH` (zsh or bash)

### Step 2: Verify Flutter is installed
Open a Terminal window and run:

`flutter --version`

If Flutter is installed correctly, this will print the installed Flutter version.

## 2) Set Up Android Development

### Step 1: Install Android Studio
Download and install Android Studio:

https://developer.android.com/studio

During installation, make sure these components are selected:
- Android SDK
- Android SDK Platform
- Android Virtual Device (AVD)

### Step 2: Follow Flutter’s Android setup instructions
Complete the Android configuration steps here:

https://docs.flutter.dev/platform-integration/android/setup

This includes:
- Installing required Android SDK versions
- Accepting Android SDK licenses
- Configuring environment variables (if required)

## 3) iOS Development Setup

If you plan to run the app on iOS simulators or physical iPhones, more setup is needed

Requirements:
- Xcode installed from the Mac App Store
- Xcode command-line tools

After installing Xcode, open it once to complete setup, then run:

`xcode-select --install`

For iOS setup instructions, got o:
https://docs.flutter.dev/platform-integration/ios/setup

## 4) Run flutter doctor

After installing Flutter and platform dependencies, run:

`flutter doctor`

This command checks your environment and reports missing requirements.

If flutter doctor shows problems, follow the suggested fixes and re-run it until the problems are fixed.

### Android licenses
If Flutter shows missing Android licenses, run:

`flutter doctor --android-licenses`

Accept the licenses, then run flutter doctor again.

## 5) Verify the Project Builds

Once your environment is ready:

1. Open a terminal in the Flutter project directory
2. Run:

`flutter pub get`   
`flutter test`

This is to make sure project compiles with all dependencies and tests run.

## 6) Recommended Tools

- VS Code with the Flutter and Dart extensions
- Android Emulator (configured w/ Android Studio)
- iOS Simulator (installed w/ Xcode)