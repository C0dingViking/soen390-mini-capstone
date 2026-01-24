# Running the App on an Android Emulator

Guide on how to create and run an Android emulator through Android Studio and launch the Flutter application on it.


## Prerequisites

Before following this guide, make sure:
- Flutter is installed and working (`flutter doctor` shows no critical errors)
- Android Studio is installed
- Android SDK and AVD components are installed (via Android Studio)


## Steps to Run on an Android Emulator

### 1. Open Android Studio Device Manager
Launch **Android Studio** and go to either **More Actions → Device Manager**, or **Tools → Device Manager** (depending on version)


### 2. Create a Virtual Device
Click **Create Device** or **Create Virtual Device** 

Choose a phone (recommended to use any modern pixel)


### 3. Choose a System Image
Select any system image with:
  - **x86_64** (recommended for Intel and AMD Windows PCs)
  - **arm64** (recommended for Apple Silicon Macs)

> Use images labeled with Google APIs for best use

- If the image is not downloaded, click **Download** -> **Finish**

### 4. Boot the Emulator
You can start the emulator in either of the following ways:
- Click the start button next to the device in Device Manager
- Start it from VS Code using the device selector
- Using the terminal through Flutter CLI:

```bash
flutter emulators --launch <emulator id>
```

> You can run `flutter emulators` to see available emulators

Wait until the emulator finishes booting completely.


### 5. Run the Flutter App

From the Flutter project directory, run:

`flutter run`

Alternatively, in **VS Code**:
- Open the project
- Select the running emulator as the target device (bottom right corner)
- Press **Run** or **F5**

The app should build and launch on the emulator.


## Common Issues

- **Slow emulator performance**  
  Ensure hardware acceleration is enabled (Intel HAXM / AMD Hypervisor / Windows Hypervisor Platform).

- **Build fails on first run**  
  Try running:
  `flutter pub get`
  before running the app again.

- **Emulator not in the list of devices**  
  Make sure the emulator is running before executing `flutter run`.

  Restart Android Studio and the emulator, then try again.

  If issues persist, run:
  `flutter emulators`
  to verify the emulator is recognized.

  If not, recreate the emulator in Android Studio.

  If the emulator is present and not running, start it with:
  `flutter emulators --launch <emulator id>` with the ID of the corresponding emulator from the previous command.



## Notes

- Only one emulator needs to be running at a time.
- Emulator setup is a one-time process; once created, it can be reused for all Flutter projects.
