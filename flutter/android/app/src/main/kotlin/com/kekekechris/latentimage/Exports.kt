package com.kekekechris.latentimage

import android.app.Activity
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Where an export lands on Android, and how it reaches the gallery.
 *
 * The engine writes by path. Android has no "save as" panel to hand it one — file_selector's
 * getSavePath is unimplemented here, and the UnimplementedError it threw is why Export did
 * nothing at all on a phone. So the engine writes into the app's own external directory, which
 * needs no permission, and the finished file is then copied into MediaStore so it appears in the
 * gallery like any other photograph.
 *
 * Android 9 has no scoped storage: filing into MediaStore there needs WRITE_EXTERNAL_STORAGE,
 * which the manifest does not ask for. On 9 the file stays in the export directory and `publish`
 * answers that path instead.
 */
class Exports(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "fotufilm/exports")
    private val work = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "directory" -> result.success(directory().path)
                "publish" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no-path", "publish needs a path", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: File(path).name
                    val mime = call.argument<String>("mime") ?: "image/jpeg"
                    work.execute {
                        val answer = runCatching { publish(File(path), name, mime) }
                        main.post {
                            answer.fold(
                                { result.success(it) },
                                { result.error("publish-failed", it.message, null) })
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** The directory the engine writes into: the app's own, so no permission is involved. */
    private fun directory(): File =
        File(activity.getExternalFilesDir(null) ?: activity.filesDir, "exports").apply { mkdirs() }

    /** Copies the finished file into the gallery. Answers a content URI, or the path on 9. */
    private fun publish(file: File, name: String, mime: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return file.path

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Latent Image")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = activity.contentResolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore refused an entry for $name")
        activity.contentResolver.openOutputStream(uri)?.use { out ->
            file.inputStream().use { it.copyTo(out, 1 shl 20) }
        } ?: throw IllegalStateException("MediaStore gave no stream for $name")

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        activity.contentResolver.update(uri, values, null, null)
        return uri.toString()
    }
}
