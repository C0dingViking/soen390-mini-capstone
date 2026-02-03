# Testing Info
Tests for the app are located in 'concordia_campus_guide/test/' directory.

## Code Coverage Report

Flutter provides built-in support for generating code coverage reports through its testing tools. When running tests with coverage enabled, Flutter collects information about which lines of code were executed and outputs this data into a coverage report file.

### Required Dependencies

To view the coverage report in a human-friendly format, you will need to convert a LCOV report into HTML files.  
To convert the LCOV report into HTML, you need the LCOV tools installed on your system.  
Flutter does not bundle these tools, so they must be installed separately depending on your operating system.

#### Arch Linux  

On Arch, LCOV can be installed using `pacman`:

```bash
sudo pacman -s lcov
```

#### macOS

On macOS, LCOV can be installed using `Homebrew`:

```bash
brew install lcov
```

#### Windows

On Windows, LCOV can be installed using `Chocolatey`:

```bash
choco install lcov
```

### Generating the Report

To generate the report, run the command below in the root folder (`concordia_campus_guide/`):

```bash
flutter test --coverage
```

This will generate the coverage report as a `lcov.info` file.
> By default, Flutter outputs this file into the `coverage/` folder

### Converting the Coverage Report from LCOV to HTML

The `lcov.info` file itself is not readable.  
To view the coverage results in a human-friendly way, you will need to convert the `lcov.info` file into HTML files.

From the root folder, execute:

```bash
genhtml coverage/lcov.info -o coverage/html
```

Or, from the `coverage/` folder, execute:

```bash
genhtml lcov.info -o html
```

This will creates an HTML report in `coverage/html/index.html`.

### Viewing the Report

#### Arch Linux

To view the report, run the command below from the root folder:

```bash
xdg-open coverage/html/index.html
```

#### macOS

To view the report, run the command below from the root folder:

```bash
open coverage/html/index.html
```

#### Windows

To view the report, run the command below in PowerShell from the root folder:

```bash
start coverage/html/index.html
```

## Continuous Integration (CI)
The project uses GitHub Actions for CI. The workflow file is located at '.github/workflows/flutter_ci.yml'. It runs on every pull request to the main and development branches (Sprint branches).

The main steps of the workflow include:
- `flutter analyze`: Runs 'flutter analyze' to check for code issues. (more robust than just running tests)
- `flutter test`: Executes the unit and widget tests located in the 'test/' directory.
- `flutter build apk --debug`: Builds the Android APK to ensure the app compiles successfully. (Outputed APK is saved as an artifact for download)