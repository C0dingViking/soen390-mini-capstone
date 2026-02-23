# Patrol Testing

## Setup

To run Patrol locally, you'll need to install [Patrol CLI](https://pub.dev/packages/patrol_cli#installation)

To verify installation:

```bash
patrol doctor
```

Expected output:
```bash
Patrol CLI version: 2.3.1+1
Android:
• Program adb found in /Users/username/Library/Android/sdk/platform-tools/adb
• Env var $ANDROID_HOME set to /Users/username/Library/Android/sdk
iOS / macOS:
• Program xcodebuild found in /usr/bin/xcodebuild
• Program ideviceinstaller found in /opt/homebrew/bin/ideviceinstaller
Web:
• Program node found in /usr/bin/node
• Program npm found in /usr/bin/npm
```
**Note**: Since we're developing for android were only concerned with the `Android` section.

### Run tests

Ensure that an Android emulator is running for test execution, or use a physical device instead.

From `concordia_campus_guide`:

```bash
patrol test
```

For specific tests:

```bash
patrol test -t patrol_test/your_test.dart
```

For a specific device, execute `patrol devices` to find the device id then use:

```bash
patrol test --device <device-id>
```

Tests filles are located in `concordia_campus_guide/patrol_test`

## Why Patrol?

For e2e testing we considered: Flutter's official integration test tooling, Maestro, and Patrol.

Flutter's integration test tooling has the advantage of being officially supported but lacks the ability to interact with native android dialogs. For our application, we will leverage android location services which require permissions. With Flutter, this requires manual or external workarounds.

Maestro is a black-box testing framework that has the advantage of being easy to setup and simple to write tests for. However, it does not provide access to Flutter’s internal application state, making it difficult to assert on ViewModel-level behavior or internal logic related to location handling.

Patrol is a grey-box testing framework that provides the functionality we need including interaction with android native dialogs and having access to Flutter's application state. The drawback is higher complexity, but with the scale of our application, it is crucial to ensure that the app does not regress.
