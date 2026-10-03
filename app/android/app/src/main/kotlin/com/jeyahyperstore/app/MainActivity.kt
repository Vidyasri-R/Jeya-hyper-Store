package com.jeyahyperstore.app

import android.content.res.Resources
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The app picks the launch splash for the NEXT start: the festival's colour while one is on.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jeya/splash").setMethodCallHandler { call, result ->
            if (call.method != "setTheme") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val theme = when (call.argument<String>("preset")) {
                    "diwali" -> R.style.DiwaliSplashTheme
                    "pongal" -> R.style.PongalSplashTheme
                    "christmas" -> R.style.ChristmasSplashTheme
                    else -> Resources.ID_NULL
                }
                splashScreen.setSplashScreenTheme(theme)
            }
            result.success(null)
        }
    }
}
