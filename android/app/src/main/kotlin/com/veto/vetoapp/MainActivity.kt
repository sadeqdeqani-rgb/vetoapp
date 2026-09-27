package com.veto.vetoapp

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vetoapp/document")
            .setMethodCallHandler { call, result ->
                if (call.method != "openPdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_path", "مسیر فایل معتبر نیست.", null)
                    return@setMethodCallHandler
                }
                try {
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
                    startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/pdf")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    })
                    result.success(null)
                } catch (exception: Exception) {
                    result.error("open_failed", exception.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vetoapp/external")
            .setMethodCallHandler { call, result ->
                if (call.method != "openUrl") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")
                if (url.isNullOrBlank() || !url.startsWith("https://t.me/")) {
                    result.error("invalid_url", "نشانی بات تلگرام معتبر نیست.", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)))
                    result.success(null)
                } catch (exception: Exception) {
                    result.error("open_failed", exception.message, null)
                }
            }
    }
}
