package com.example.concordia_campus_guide

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "concordia_campus_guide/api_keys"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getGoogleMapsApiKey" -> {
						val key = readGoogleMapsApiKey()
						result.success(key)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun readGoogleMapsApiKey(): String? {
		return try {
			val appInfo = packageManager.getApplicationInfo(
				packageName,
				PackageManager.GET_META_DATA,
			)
			val meta = appInfo.metaData
			meta?.getString("com.google.android.geo.API_KEY")
		} catch (e: Exception) {
			null
		}
	}
}
