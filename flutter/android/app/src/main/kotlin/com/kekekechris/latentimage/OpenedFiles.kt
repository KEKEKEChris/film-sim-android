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
                    intent.addCategory(Intent.CATEGORY_OPENABLE)
                    intent.setType("*/*")
                    intent.putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
                    intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    try {
                        activity.startActivityForResult(intent, REQUEST)
                    } catch (e: Exception) {
                        waiting = null
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }
                "openPhotos" -> {
                    waiting?.success(emptyList<String>())
                    waiting = result
                    val types = call.argument<List<String>>("types") ?: listOf("image/*", "video/*")
                    launchPhotoPicker(types)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * The system photo picker on Android 13 and later (MediaStore.ACTION_PICK_IMAGES): it shows
     * the gallery itself with photo/video grids, albums and date grouping, with no storage
     * permission and no file tree to walk. On older devices, it falls back to the system Gallery
     * (ACTION_PICK), ACTION_GET_CONTENT, and finally ACTION_OPEN_DOCUMENT.
     *
     * `types` is what the caller asked for: images, videos, or both.
     */
    private fun launchPhotoPicker(types: List<String>) {
        val hasImage = types.any { it.startsWith("image/") }
        val hasVideo = types.any { it.startsWith("video/") }

        // Strategy 1: Android 13+ System Photo Picker (MediaStore.ACTION_PICK_IMAGES)
        try {
            val intent = Intent("android.provider.action.PICK_IMAGES")
            if (hasImage && !hasVideo) {
                intent.type = "image/*"
            } else if (!hasImage && hasVideo) {
                intent.type = "video/*"
            }
            intent.putExtra("android.provider.extra.PICK_IMAGES_MAX", 100)
            activity.startActivityForResult(intent, REQUEST_PHOTOS)
            return
        } catch (_: Exception) {}

        // Strategy 2: System Gallery via ACTION_PICK
        try {
            val intent = Intent(Intent.ACTION_PICK)
            if (hasImage && !hasVideo) {
                intent.setDataAndType(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/*")
            } else if (!hasImage && hasVideo) {
                intent.setDataAndType(android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "video/*")
            } else {
                intent.setDataAndType(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/*")
                intent.putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            }
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            activity.startActivityForResult(intent, REQUEST_PHOTOS)
            return
        } catch (_: Exception) {}

        // Strategy 3: ACTION_GET_CONTENT
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT)
            intent.addCategory(Intent.CATEGORY_OPENABLE)
            if (hasImage && !hasVideo) {
                intent.type = "image/*"
            } else if (!hasImage && hasVideo) {
                intent.type = "video/*"
            } else {
                intent.type = "*/*"
                intent.putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
            }
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            activity.startActivityForResult(intent, REQUEST_PHOTOS)
            return
        } catch (_: Exception) {}

        // Fallback: ACTION_OPEN_DOCUMENT
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.setType("*/*")
        intent.putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        try {
            activity.startActivityForResult(intent, REQUEST_PHOTOS)
        } catch (e: Exception) {
            val res = waiting
            waiting = null
            res?.error("PICK_FAILED", e.message, null)
        }
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
