package com.kekekechris.latentimage

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/** The editor (lib/) in Flutter's activity, with the engine's films unpacked before Dart starts. */
class MainActivity : FlutterActivity() {
    private var openedFiles: OpenedFiles? = null
    private var exports: Exports? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        EngineResources.prepare(this)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        openedFiles = OpenedFiles(this, flutterEngine.dartExecutor.binaryMessenger)
        exports = Exports(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (openedFiles?.onActivityResult(requestCode, resultCode, data) == true) return
        if (exports?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}
