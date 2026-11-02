package my.duitkita.app

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Google API keys restricted to this Android app check two request
        // headers: the package name and the SHA-1 of the signing certificate.
        // Play re-signs the app, so the certificate can only be read at runtime.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duitkita/app_identity")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "identity" -> result.success(
                        mapOf("package" to packageName, "sha1" to signingSha1())
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun signingSha1(): String? = try {
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                packageName, PackageManager.GET_SIGNING_CERTIFICATES
            )
            val signing = info.signingInfo
            when {
                signing == null -> null
                signing.hasMultipleSigners() -> signing.apkContentsSigners?.firstOrNull()
                // History runs oldest first; the current key is the last one.
                else -> signing.signingCertificateHistory?.lastOrNull()
            }
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                .signatures?.firstOrNull()
        }
        signature?.let { sig ->
            MessageDigest.getInstance("SHA-1").digest(sig.toByteArray())
                .joinToString("") { "%02X".format(it) }
        }
    } catch (e: Exception) {
        null
    }
}
