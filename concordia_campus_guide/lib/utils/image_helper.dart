import "package:flutter/material.dart";

/// Extension to help handle images that can be either asset paths or web URLs
extension ImageStringExtension on String {
  /// Checks if the string is a web URL
  bool get isUrl => startsWith("http://") || startsWith("https://");

  /// Checks if the string is an asset path
  bool get isAsset => !isUrl;

  /// Returns an appropriate Image widget based on the string type
  Widget toImage({
    final BoxFit? fit,
    final double? width,
    final double? height,
    final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    if (isUrl) {
      return Image.network(
        this,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    } else {
      return Image.asset(
        this,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
      );
    }
  }

  /// Returns an appropriate ImageProvider based on the string type
  ImageProvider toImageProvider() {
    if (isUrl) {
      return NetworkImage(this);
    } else {
      return AssetImage(this);
    }
  }
}
