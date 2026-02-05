# Code Generation

Use `build_runner` and `json_serializable` to generate `.g.dart` files generated and should not be manually edited.

## Generate Code

After modifying models with `@JsonSerializable`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Custom Converters

For non-standard types, converters are in `lib/domain/converters/`. Apply them with annotations:

```dart
@CoordinateConverter()
final Coordinate location;
```

## Analyzer

The generated files must be  ignored by the analyzer.

## References

- [json_serializable package](https://pub.dev/packages/json_serializable)
