package com.kekekechris.latentimage

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
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
    private var waiting: MethodChannel.Result? = null
    private val channel = MethodChannel(messenger, "fotufilm/exports")
    private val work = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "directory" -> result.success(directory().path)
                "chooseDirectory" -> {
                    waiting = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }
                    activity.startActivityForResult(intent, REQUEST_DIRECTORY)
                }
                "share" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no-path", "share needs a path", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: File(path).name
                    val mime = mimeFor(name)
                    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        androidx.core.content.FileProvider.getUriForFile(
                            activity, "${activity.packageName}.fileprovider", File(path))
                    } else {
                        Uri.fromFile(File(path))
                    }
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TEXT, name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(Intent.createChooser(intent, "Share $name"))
                    result.success(true)
                }
                "publish" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no-path", "publish needs a path", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: File(path).name
                    val mime = call.argument<String>("mime") ?: "image/jpeg"
                    val directoryUri = call.argument<String>("directoryUri")
                    work.execute {
                        val answer = runCatching { publish(File(path), name, mime, directoryUri) }
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

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_DIRECTORY) return false
        val result = waiting ?: return true
        waiting = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }
        val uri = data.data!!
        runCatching {
            activity.contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        result.success(uri.toString())
        return true
    }

    /** The directory the engine writes into: the app's own, so no permission is involved. */
    private fun directory(): File =
        File(activity.getExternalFilesDir(null) ?: activity.filesDir, "exports").apply { mkdirs() }

    private companion object {
        const val REQUEST_DIRECTORY = 0x0f09
    }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "png" -> "image/png"
        "tif", "tiff" -> "image/tiff"
        "heic", "heif" -> "image/heic"
        "webp" -> "image/webp"
        "mp4", "m4v" -> "video/mp4"
        "mov" -> "video/quicktime"
        else -> "image/jpeg"
    }

    /** Copies the finished file into a chosen SAF tree or the Latent Image gallery folder. */
    private fun publish(file: File, name: String, mime: String, directoryUri: String?): String {
        if (directoryUri != null && directoryUri.isNotEmpty()) {
            val tree = Uri.parse(directoryUri)
            val parent = DocumentsContract.buildDocumentUriUsingTree(
                tree, DocumentsContract.getTreeDocumentId(tree))
            val document = DocumentsContract.createDocument(
                activity.contentResolver, parent, mime, name)
                ?: throw IllegalStateException("Android refused an entry for $name")
            activity.contentResolver.openOutputStream(document)?.use { out ->
                file.inputStream().use { it.copyTo(out, 1 shl 20) }
            } ?: throw IllegalStateException("Android gave no stream for $name")
            return document.toString()
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return file.path

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Latent Image")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = if (mime.startsWith("video/")) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
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
