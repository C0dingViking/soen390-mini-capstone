# Running Flutter Apps (Terminal & VS Code) — Windows, macOS, Linux

Guide on how to run Flutter apps from VS Code and the terminal, and how the differences across **Windows**, **macOS**, and **Linux**.


## 1) Running from the Terminal (All Platforms)

### Step 1 — Install dependencies
From the project directory, run:

`flutter pub get`

### Step 2 — Check available devices
List all connected/running devices (emulators, simulators, physical devices):

`flutter devices`

If your emulator/simulator is running, you should see it in the list.

### Step 3 — Run the app
To run on the currently selected device:

`flutter run`

Flutter will build and launch the app.

### Step 4 — Hot reload and hot restart
While `flutter run` is active in the terminal:
- Press `r` for **hot reload**
- Press `R` for **hot restart**
- Press `q` to **quit**
- Press `p` to toggle debug paint (to see wireframe of each widget)


## 2) Selecting a Specific Device (Terminal)

If multiple devices are available, specify one:

1) Find the device ID:

`flutter devices`

2) Run using the device ID:

`flutter run -d <device_id>`
Example device IDs
- `emulator-5554`
- `chrome`
- `macos`
- `windows`

## 3) Running from VS Code (All Platforms)

Step 1: Install extensions
Make sure VS Code has this extension installed:
- Flutter

Step 2: Open the project
Open the folder that contains `pubspec.yaml`.

Step 3: Select a device
At the bottom-right of VS Code, choose the current device (it may say “No Device”).
Select your running emulator/simulator or a connected phone.

Step 4: Run
Can be done with any of these methods:
- Run → Start Debugging
- Press **F5**
- Click Run and Debug (sidebar)

### Hot reload/restart in VS Code
- Hot reload is available through the debug toolbar (lightning icon)
- Hot restart is also available from the debug toolbar


## 4) Platform Specific Notes

### Windows
Commands are the same as above. If you use PowerShell or Command Prompt, either is fine.

### macOS
macOS supports:
- Android Emulator
- iOS Simulator (requires Xcode)
- Physical iPhone (requires Apple developer setup)
- macOS desktop apps

### Linux
Linux can also build Linux desktop apps

## 5) Useful Commands (Quick Reference)

- Install dependencies:
  `flutter pub get`

- Verify environment:
  `flutter doctor`

- List devices:
  `flutter devices`

- Run on default device:
  `flutter run`

- Run on a specific device:
  `flutter run -d <device_id>`

- Build APK (Android):
  `flutter build apk`

- Clean build outputs:
  `flutter clean`
  `flutter pub get`
## 6) Troubleshooting

- Hot reload not working: Hot restart might be necessary for some more major changes.