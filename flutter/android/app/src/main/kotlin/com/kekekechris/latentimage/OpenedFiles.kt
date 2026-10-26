package com.kekekechris.latentimage

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Photographs, scans and movies chosen in the system's picker, as files the engine opens by path
 * (`chooseFiles` and `choosePhotos` in lib/model/file_types.dart, over `fotufilm/files`). The
 * picker answers with content URIs; each is copied into the app's cache a buffer at a time, so a
 * camera's RAW or a scan of any size crosses without being held in memory, which file_selector
 * does and runs out of.
 *
 * Two doors, because a photographer means two different things by "import". `openPhotos` is the
 * gallery: the system's photo picker, listing what the device has indexed as a picture, which is
 * what someone tapping a photo app expects to see. `open` is the file manager, for a RAW on an SD
 * card or a scan in Downloads that no gallery has indexed.
 */
class OpenedFiles(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "fotufilm/files")
    private val copying = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var waiting: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    waiting?.success(emptyList<String>())
                    waiting = result
                    val types = call.argument<List<String>>("types") ?: listOf("image/*", "video/*")
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*")
                        .putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
                        .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    activity.startActivityForResult(intent, REQUEST)
                }
                "openPhotos" -> {
                    waiting?.success(emptyList<String>())
                    waiting = result
                    val types = call.argument<List<String>>("types") ?: listOf("image/*", "video/*")
                    activity.startActivityForResult(photoPicker(types), REQUEST_PHOTOS)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * The system photo picker on Android 13 and later: it shows the gallery itself, with no
     * storage permission and no file tree to walk. Older phones get a document picker narrowed to
     * the same types, which their gallery apps answer — the same list in practice, one tap away.
     *
     * `types` is what the caller asked for: the editor asks for images and video together, so the
     * picker must not narrow itself to `image/*` or the videos never appear.
     */
    private fun photoPicker(types: List<String>): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
    }

    /** The picker's answer; false when the result is another request's. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST && requestCode != REQUEST_PHOTOS) return false
        val result = waiting ?: return true
        waiting = null
        val uris = buildList {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val clip = data.clipData
                if (clip != null) for (i in 0 until clip.itemCount) add(clip.getItemAt(i).uri)
                else data.data?.let(::add)
            }
        }
        copying.execute {
            val paths = uris.mapNotNull { uri -> runCatching { copy(uri) }.getOrNull() }
            main.post { result.success(paths) }
        }
        return true
    }

    /** `uri` in a folder of its own under the cache, under its own name (its extension says what
     *  it is to the engine). */
    private fun copy(uri: Uri): String {
        val name = displayName(uri)?.replace('/', '_') ?: "photo"
        val folder = File(activity.cacheDir, "opened/${System.nanoTime()}").apply { mkdirs() }
        val target = File(folder, name)
        activity.contentResolver.openInputStream(uri)!!.use { input ->
            target.outputStream().use { input.copyTo(it, 1 shl 20) }
        }
        return target.path
    }

    private fun displayName(uri: Uri): String? =
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }

    private companion object {
        const val REQUEST = 0x0f07
        const val REQUEST_PHOTOS = 0x0f08
    }
}
