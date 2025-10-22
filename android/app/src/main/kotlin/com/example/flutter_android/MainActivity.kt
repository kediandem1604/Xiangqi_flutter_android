package com.example.flutter_android

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app_paths")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNativeLibraryDir" -> {
                        val dir = applicationContext.applicationInfo.nativeLibraryDir
                        Log.d("MainActivity", "Native library dir: $dir")
                        result.success(dir)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
