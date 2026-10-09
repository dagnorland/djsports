package com.dagnorland.djsports

import android.content.pm.PackageManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.djsports/app_signature",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSigningSha1" -> result.success(signingSha1())
                else -> result.notImplemented()
            }
        }
    }

    // SHA-1 of the certificate this install is signed with. Spotify's
    // Android SDK only accepts apps whose package name + SHA-1 are
    // registered in the Developer Dashboard. A Play Store install is
    // signed with Google's app signing key, a sideloaded APK with the
    // upload key, so read it at runtime instead of hard-coding one.
    @Suppress("DEPRECATION")
    private fun signingSha1(): String? {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            ).signingInfo?.apkContentsSigners
        } else {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES,
            ).signatures
        }
        val cert = signatures?.firstOrNull() ?: return null
        return MessageDigest.getInstance("SHA-1")
            .digest(cert.toByteArray())
            .joinToString(":") { "%02X".format(it) }
    }
}
