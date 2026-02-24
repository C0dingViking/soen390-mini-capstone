# Format Dart Code

Dart provides a code formatter. This formatter follows the [Dart style guide](https://dart.dev/effective-dart/style#formatting).  
Examples for some specific rules can be found at this [GitHub wiki](https://github.com/dart-lang/dart_style/wiki/Formatting-Rules).  
We will use this provided formatter since it is the formatter recommended by Dart and it is the one used by Dart, Flutter and even Google.  

## Running the Formatter via the CLI

Executing formatter via the CLI requires you to run a simple command from the `concordia_campus_guide` folder:

```bash
dart format .
```

This will format all the `.dart` files under the `concordia_campus_guide` folder.
> Available commands can be found on [Dart's documentation](https://dart.dev/tools/dart-format)

## Automatically Format Dart Code (VS Code)

This section will explain how to set up VS Code to automatically format Dart code on save based on this [documentation](https://dart.dev/tools/dart-format#vs-code).  
> See this section of the [Dart documentation](https://dart.dev/tools/dart-format#intellij-and-android-studio)

### Preconditions

You need to have installed the [Dart extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.dart-code).

### Configuration

Configuring VS Code to format Dart code automatically when saving requires the addition of the below snippet into your `.vscode/settings.json` file:

```json
{
  ...
  "[dart]": {
    "editor.formatOnSave": true
  }
  ...
}

```

#### Further VS Code configuration

To help ensure that new files and code will follow the recommended, you can further configure VS Code in via the `.vscode/settings.json` file.  It is recommended to add these configurations to VS Code:

```json
{
  ...
  "[dart]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 2,
    "editor.detectIndentation": false
  }
  ...
}
```

This will make VS Code use spaces instead of tabs, set the tab size to 2 and not set the indentation of new dart files based on other files in the project. These settings are based on the Dart code style and are the ones implemented by the formatter.
