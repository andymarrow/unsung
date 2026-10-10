package com.andymarrow.unsung

import android.content.Intent
import com.andymarrow.unsung.audio.AudioEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app. Besides the audio engine it receives text shared
 * from other apps (Share → Unsung from YouTube) on the unsung/share channel:
 * `initialText` returns what launched the app (once); later shares are pushed
 * to Dart as `shared`.
 */
class MainActivity : FlutterActivity() {
    private var audio: AudioEngine? = null
    private var share: MethodChannel? = null
    private var pendingText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audio = AudioEngine(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        pendingText = sharedText(intent)
        share = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unsung/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initialText") {
                    result.success(pendingText)
                    pendingText = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharedText(intent)?.let { share?.invokeMethod("shared", it) }
    }

    private fun sharedText(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audio?.dispose()
        audio = null
        share?.setMethodCallHandler(null)
        share = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
