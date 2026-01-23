## Testing Info
Tests for the app are located in 'concordia_campus_guide/test/' directory.

### Continuous Integration (CI)
The project uses GitHub Actions for CI. The workflow file is located at '.github/workflows/flutter_ci.yml'. It runs on every push and pull request to the main branch.

The main steps of the workflow include:
- `flutter analyze`: Runs 'flutter analyze' to check for code issues. (more robust than just running tests)
- `flutter test`: Executes the unit and widget tests located in the 'test/' directory.
- `flutter build apk --debug`: Builds the Android APK to ensure the app compiles successfully. (Outputed APK is saved as an artifact for download)