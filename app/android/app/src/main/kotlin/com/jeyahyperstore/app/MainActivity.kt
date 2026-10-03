package com.jeyahyperstore.app

import android.content.res.Resources
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The app picks the launch splash for the NEXT start: festive while a festival theme is on.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jeya/splash").setMethodCallHandler { call, result ->
            if (call.method != "setFestive") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val festive = call.argument<Boolean>("festive") == true
                splashScreen.setSplashScreenTheme(if (festive) R.style.FestiveSplashTheme else Resources.ID_NULL)
            }
            result.success(null)
        }
    }
}
