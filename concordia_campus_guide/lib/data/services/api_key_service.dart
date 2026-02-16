import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";
class ApiKeyService {
	static const MethodChannel _channel = MethodChannel(
		"concordia_campus_guide/api_keys",
	);

	Future<String?> getGoogleMapsApiKey() async {
		if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
			return null;
		}

		try {
			final key = await _channel.invokeMethod<String>(
				"getGoogleMapsApiKey",
			);
			if (key == null || key.trim().isEmpty) return null;
			return key;
		} catch (e, stackTrace) {
            logger.e(
                "ApiKeyService: failed to get the Google Maps API key",
                error: e,
                stackTrace: stackTrace,
            );
			return null;
		}
	}
}
