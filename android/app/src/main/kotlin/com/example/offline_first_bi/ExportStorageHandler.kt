package com.example.offline_first_bi

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ExportStorageHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private var pendingPermission: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val folder = call.argument<String>("folder") ?: ""
            when (call.method) {
                "ensurePermission" -> ensurePermission(result)
                "exists" -> result.success(
                    exists(folder, call.argument<String>("fileName") ?: ""),
                )
                "save" -> result.success(
                    save(
                        folder,
                        call.argument<String>("sourcePath") ?: "",
                        call.argument<String>("fileName") ?: "",
                        call.argument<String>("mimeType") ?: "application/octet-stream",
                    ),
                )
                "openFolder" -> result.success(openFolder(folder, call.argument<String>("step") ?: ""))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("export_storage", e.message, null)
        }
    }

    private fun needsPermission(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    private fun hasPermission(): Boolean {
        if (!needsPermission()) return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return activity.checkSelfPermission(WRITE_PERMISSION) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensurePermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success("granted")
            return
        }
        if (pendingPermission != null) {
            result.error("export_storage", "permission request in progress", null)
            return
        }
        pendingPermission = result
        activity.requestPermissions(arrayOf(WRITE_PERMISSION), PERMISSION_REQUEST_CODE)
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val result = pendingPermission ?: return
        pendingPermission = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        when {
            granted -> result.success("granted")
            activity.shouldShowRequestPermissionRationale(WRITE_PERMISSION) ->
                result.success("denied")
            else -> result.success("permanentlyDenied")
        }
    }

    private fun relativePath(folder: String): String = "${Environment.DIRECTORY_DOWNLOADS}/$folder"

    private fun legacyDirectory(folder: String): File =
        File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), folder)

    private fun exists(folder: String, fileName: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cursor = activity.contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?",
                arrayOf(relativePath(folder) + "/", fileName),
                null,
            )
            cursor?.use { return it.count > 0 }
            return false
        }
        return File(legacyDirectory(folder), fileName).exists()
    }

    private fun save(folder: String, sourcePath: String, fileName: String, mimeType: String): String {
        val source = File(sourcePath)
        if (!source.exists()) throw IllegalStateException("source file missing")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(folder, source, fileName, mimeType)
        } else {
            saveToDirectory(folder, source, fileName)
        }
    }

    private fun saveWithMediaStore(folder: String, source: File, fileName: String, mimeType: String): String {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath(folder))
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("could not create file")
        try {
            val output = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("could not open file")
            output.use { out -> source.inputStream().use { it.copyTo(out) } }
            val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            resolver.update(uri, done, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0)
        }
        return fileName
    }

    private fun saveToDirectory(folder: String, source: File, fileName: String): String {
        val directory = legacyDirectory(folder)
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("could not create folder")
        }
        val dot = fileName.lastIndexOf('.')
        val base = if (dot <= 0) fileName else fileName.substring(0, dot)
        val extension = if (dot <= 0) "" else fileName.substring(dot)
        var target = File(directory, fileName)
        var counter = 1
        while (target.exists()) {
            target = File(directory, "$base ($counter)$extension")
            counter++
        }
        try {
            source.inputStream().use { input ->
                target.outputStream().use { input.copyTo(it) }
            }
        } catch (e: Exception) {
            target.delete()
            throw e
        }
        MediaScannerConnection.scanFile(activity, arrayOf(target.absolutePath), null, null)
        return target.name
    }

    private fun openFolder(folder: String, step: String): Boolean {
        val intent = when (step) {
            "directory" -> folderIntent(folder, DocumentsContract.Document.MIME_TYPE_DIR)
            else -> return false
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    private fun folderIntent(folder: String, type: String): Intent {
        val uri = DocumentsContract.buildDocumentUri(
            FOLDER_AUTHORITY,
            "primary:${Environment.DIRECTORY_DOWNLOADS}/$folder",
        )
        return Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, type)
        }
    }

    companion object {
        private const val CHANNEL = "offline_first_bi/export_storage"
        private const val PERMISSION_REQUEST_CODE = 7301
        private const val WRITE_PERMISSION = "android.permission.WRITE_EXTERNAL_STORAGE"
        private const val FOLDER_AUTHORITY = "com.android.externalstorage.documents"
    }
}
