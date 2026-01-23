# Flutter Setup Guide (Windows)

This is a guide for how to set up Flutter on Windows.
It covers installing Flutter, configuring Android development, and verifying your setup.

Note: This guide assumes you are using **Windows 10 or later** and have administrator access.

---

## 1) Install Flutter SDK

Flutter’s official installation instructions should always be followed, since they are kept up to date.

### Step 1: Follow official Flutter install guide

Install Flutter by following the Windows instructions here:

- Installation: https://docs.flutter.dev/install/quick

### Step 2: Verify Flutter is installed

Open a Command Prompt or PowerShell window and run:

`flutter --version`

If Flutter is installed correctly, this will print the Flutter version.

### Note:

Do not install Dart SDK separately; Flutter includes its own Dart SDK.

## 2) Set Up Android Development

Android setup is required to build and run this project on Android devices or emulators.

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
- Configuring environment variables (if needed)


## 3) Run flutter doctor

After installing Flutter and Android dependencies, run:

`flutter doctor`

This command checks your environment and reports missing requirements.

If flutter doctor shows problems, follow the suggested fixes and re-run it until the issues are fixed.

### Android licenses

If Flutter shows missing Android licenses, run:

`flutter doctor --android-licenses`

Accept the licenses, then run flutter doctor again.

## 4) Verify the Project Builds

1. Open a terminal in the Flutter project directory
2. Run:

`flutter pub get`   
`flutter test`

This is to make sure project compiles with all dependencies and tests run.


## 5) Recommended Tools

- VS Code with the Flutter and Dart extensions
- Android Emulator configured in Android Studio


## Troubleshooting

- If flutter commands are not recognized, restart your terminal and check Flutter is on your PATH.
- `where flutter` command helped me troubleshoot PATH issues.