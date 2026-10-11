package com.txorav.andbox

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Base64
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.txorav.andbox/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeLibraryDir" -> {
                    result.success(applicationInfo.nativeLibraryDir)
                }
                "isStorageManager" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                }
                "requestStoragePermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("PERMISSION_ERROR", e.message, null)
                            }
                        } catch (e2: Exception) {
                            result.error("PERMISSION_ERROR", e2.message, null)
                        }
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "getApkDetails" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val pm = packageManager
                        @Suppress("DEPRECATION")
                        val flags = PackageManager.GET_PERMISSIONS or PackageManager.GET_ACTIVITIES or PackageManager.GET_META_DATA
                        val pi = pm.getPackageArchiveInfo(filePath, flags)
                        if (pi == null) {
                            result.error("PARSE_ERROR", "Failed to parse APK archive info", null)
                            return@setMethodCallHandler
                        }

                        val appInfo = pi.applicationInfo
                        if (appInfo != null) {
                            appInfo.sourceDir = filePath
                            appInfo.publicSourceDir = filePath
                        }

                        val appLabel = if (appInfo != null) {
                            try {
                                pm.getApplicationLabel(appInfo).toString()
                            } catch (e: Exception) {
                                file.nameWithoutExtension
                            }
                        } else {
                            file.nameWithoutExtension
                        }

                        val packageName = pi.packageName ?: ""
                        val versionName = pi.versionName ?: ""
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pi.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pi.versionCode.toLong()
                        }
                        val minSdk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && appInfo != null) {
                            appInfo.minSdkVersion
                        } else {
                            1
                        }
                        val targetSdk = appInfo?.targetSdkVersion ?: 1
                        val permissions = pi.requestedPermissions?.toList() ?: emptyList<String>()

                        var iconBase64: String? = null
                        if (appInfo != null) {
                            try {
                                val iconDrawable = appInfo.loadIcon(pm)
                                if (iconDrawable != null) {
                                    val bitmap = drawableToBitmap(iconDrawable)
                                    val stream = ByteArrayOutputStream()
                                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                                    iconBase64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                                }
                            } catch (_: Exception) {}
                        }

                        val resultMap = HashMap<String, Any?>()
                        resultMap["appName"] = appLabel
                        resultMap["packageName"] = packageName
                        resultMap["versionName"] = versionName
                        resultMap["versionCode"] = versionCode
                        resultMap["minSdk"] = minSdk
                        resultMap["targetSdk"] = targetSdk
                        resultMap["permissions"] = permissions
                        resultMap["iconBase64"] = iconBase64
                        resultMap["fileSizeBytes"] = file.length()

                        result.success(resultMap)
                    } catch (e: Exception) {
                        result.error("APK_DETAILS_ERROR", e.message, null)
                    }
                }
                "openWithSystem" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val contentUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val chooser = Intent.createChooser(intent, "Open with...").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_ERROR", e.message, null)
                    }
                }
                "installSplitApks" -> {
                    val apkPaths = call.argument<List<String>>("apkPaths")
                    if (apkPaths.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "apkPaths cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val packageInstaller = packageManager.packageInstaller
                        val params = PackageInstaller.SessionParams(
                            PackageInstaller.SessionParams.MODE_FULL_INSTALL
                        )
                        val sessionId = packageInstaller.createSession(params)
                        val session = packageInstaller.openSession(sessionId)

                        for (path in apkPaths) {
                            val f = File(path)
                            if (!f.exists() || !f.isFile) continue
                            val name = f.name
                            f.inputStream().use { input ->
                                session.openWrite(name, 0, f.length()).use { output ->
                                    input.copyTo(output)
                                    session.fsync(output)
                                }
                            }
                        }

                        val intent = Intent(this, MainActivity::class.java).apply {
                            action = "com.txorav.andbox.ACTION_INSTALL_COMPLETE"
                        }
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        val pendingIntent = PendingIntent.getActivity(this, sessionId, intent, flags)
                        session.commit(pendingIntent.intentSender)
                        session.close()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}

