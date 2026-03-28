import "dart:convert";

import "package:flutter/services.dart";

class RoomManifestLoader {
  static const String roomManifestAssetPath = "assets/floorplans/room_manifest.json";
  static final Map<String, List<String>> _cacheByPath = <String, List<String>>{};

  static Future<List<String>> loadRoomNames({
    final Future<String> Function(String path)? loader,
    final String path = roomManifestAssetPath,
    final bool useCache = true,
  }) async {
    if (useCache) {
      final cached = _cacheByPath[path];
      if (cached != null) {
        return List<String>.unmodifiable(cached);
      }
    }

    final fileLoader = loader ?? rootBundle.loadString;
    final roomManifest = await fileLoader(path);
    final decoded = jsonDecode(roomManifest);
    if (decoded is! List) {
      throw const FormatException("Room manifest must be a JSON array");
    }

    final rooms = List<String>.from(decoded);
    if (useCache) {
      _cacheByPath[path] = rooms;
    }

    return rooms;
  }

  static void clearCache() {
    _cacheByPath.clear();
  }
}
