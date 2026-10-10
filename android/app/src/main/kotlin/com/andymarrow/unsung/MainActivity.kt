package com.andymarrow.unsung

import com.andymarrow.unsung.audio.AudioEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var audio: AudioEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audio = AudioEngine(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audio?.dispose()
        audio = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
