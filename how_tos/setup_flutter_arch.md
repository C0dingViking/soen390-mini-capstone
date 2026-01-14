# Flutter setup on Arch Linux

[VSCode](https://aur.archlinux.org/packages/visual-studio-code-bin) and [Android Studio](https://aur.archlinux.org/packages/android-studio) used for android development.

## VSCode extensions

- [Flutter - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)

more information [Set up and test drive Flutter](https://docs.flutter.dev/get-started/quick#install)

## Flutter SDK

The Flutter SDK is needed to create/use Flutter. Therefore when creating your first Flutter project, VS Code will prompt you to install the SDK if it cannot detect it.

To create a new project, open the command palette and type `Flutter: New Project`. After doing so, VS Code will prompt you to install the Flutter SDK. Select the `Intall SDK` option.

Install to `~/Downloads/`. Move the installed flutter folder into `/opt/` with `mv ~/Downloads/flutter /opt/.` and make a symbolic link `sudo ln -s /opt/flutter/bin/flutter /usr/bin/flutter` to have access to the executable from your shell.

This will create a conflict in VSCode since it still thinks flutter is in ~/Downloads . To resolve this, hit the notifiction popup when launching vscode and edit the path in `settings.json` to `/opt/flutter/`.

## Android Studio

Install [AUR (en) - android-studio](https://aur.archlinux.org/packages/android-studio). 

### If using a wayland window manager

Locate `/usr/share/applications/android-studio.desktop` and edit the `Exec=android-studio %f` to an env var like so: `Exec=env QT_QPA_PLATFORM=xcb android-studio %f`. More info [Android emulator can't find the wayland QT plugin - Android Enthusiasts Stack Exchange](https://android.stackexchange.com/questions/216898/android-emulator-cant-find-the-wayland-qt-plugin).

### Emulator setup

Follow the relevant section of this guide to create your device: [Set up Android development](https://docs.flutter.dev/platform-integration/android/setup). 

Make sure it runs from the Virtual Device Manager before moving to the next step.

### SDK Tools

Flutter relies on `Android SDK Command-line Tools` which are not installed by default. To grab them, navigate to SDK manager in the same dropdown used to access the Virtual Device Manager and open SDK Tools. Select the Android SDK Command-line Tools and apply. 

Execute `flutter doctor`. This should detect your android sdk without any errors. 

My output:

```bash
•   flutter doctor
Doctor summary (to see all details, run flutter doctor -v):
[!] Flutter (Channel stable, 3.38.6, on EndeavourOS 6.17.9-arch1-1, locale en_CA.UTF-8)
    ! Warning: `dart` on your path resolves to /opt/dart-sdk/bin/dart, which is not inside your current Flutter SDK checkout
      at /opt/flutter. Consider adding /opt/flutter/bin to the front of your path.
[✓] Android toolchain - develop for Android devices (Android SDK version 36.1.0)
[✗] Chrome - develop for the web (Cannot find Chrome executable at google-chrome)
    ! Cannot find Chrome. Try setting CHROME_EXECUTABLE to a Chrome executable.
[✓] Linux toolchain - develop for Linux desktop
[✓] Connected device (1 available)
[✓] Network resources

! Doctor found issues in 2 categories.
```

### Emulator

Flutter can manage emulators for you. 

Execute `flutter emulators` to view the list and `QT_QPA_PLATFORM="wayland;xcb" flutter emulators --launch <emulator id>` to start the emulator. 

Don't forget to hit the power button to power the phone up.

*Start the emulator before you begin development to ensure you can run the Dart application on said emulator.*
  
### Development

Navigate to the directory of a flutter project in VSCode.

Open the Flutter sidebar and select the emulated phone you launched under Devices.

Navigate to `lib/main.dart` (or any dart file) and hit `F5`. This should compile the project and launch the app on the phone automatically.