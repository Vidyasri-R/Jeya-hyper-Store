package com.jeyahyperstore.staff

import android.content.ClipboardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "Paste photo": a picture copied in Chrome / Gallery ("Copy image") sits on the clipboard as a
        // content:// link; Flutter's own Clipboard only reads text.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jeya/clipboard").setMethodCallHandler { call, result ->
            if (call.method != "readImage") return@setMethodCallHandler result.notImplemented()
            try {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = clipboard.primaryClip
                var found: Map<String, Any>? = null
                if (clip != null) {
                    for (i in 0 until clip.itemCount) {
                        val uri = clip.getItemAt(i).uri ?: continue
                        val type = contentResolver.getType(uri) ?: continue
                        if (!type.startsWith("image/")) continue
                        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: continue
                        found = mapOf("bytes" to bytes, "type" to type)
                        break
                    }
                }
                result.success(found)
            } catch (e: Exception) {
                result.error("clipboard", e.message, null)
            }
        }
    }
}
