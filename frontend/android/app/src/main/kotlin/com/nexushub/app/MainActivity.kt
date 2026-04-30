package com.nexushub.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * MainActivity — NexusHub
 *
 * Além do edge-to-edge nativo, expõe um MethodChannel para compartilhamento
 * direcionado de cards de comunidade em apps sociais instalados.
 */
class MainActivity : FlutterActivity() {
    private val socialShareChannel = "nexushub/social_share"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Habilitar edge-to-edge: o conteúdo Flutter se estende por baixo das
        // barras de sistema (status bar e navigation bar).
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Android 15+ (API 35 / VANILLA_ICE_CREAM): edge-to-edge é enforçado
        // pelo sistema. Garantir barras de sistema transparentes explicitamente
        // para evitar que o sistema aplique cores sólidas automáticas.
        if (Build.VERSION.SDK_INT >= 35) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, socialShareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareCommunityCard" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args == null) {
                            result.success(mapOf("success" to false, "error" to "invalid_args"))
                            return@setMethodCallHandler
                        }
                        val target = args["target"] as? String ?: "more"
                        val imagePath = args["imagePath"] as? String ?: ""
                        val text = args["text"] as? String ?: ""
                        val url = args["url"] as? String ?: ""
                        val subject = args["subject"] as? String ?: "NexusHub"
                        val response = shareCommunityCard(target, imagePath, text, url, subject)
                        result.success(response)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareCommunityCard(
        target: String,
        imagePath: String,
        text: String,
        url: String,
        subject: String
    ): Map<String, Any> {
        val imageFile = File(imagePath)
        if (!imageFile.exists()) {
            return mapOf("success" to false, "error" to "image_not_found")
        }

        val imageUri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.nexushub_share_provider",
            imageFile
        )

        return when (target) {
            "instagram_stories" -> shareToInstagramStories(imageUri, url)
            "instagram_feed" -> shareToPackage(imageUri, text, subject, listOf("com.instagram.android"))
            "whatsapp" -> shareToPackage(imageUri, text, subject, listOf("com.whatsapp", "com.whatsapp.w4b"))
            "telegram" -> shareToPackage(imageUri, text, subject, listOf("org.telegram.messenger", "org.thunderdog.challegram"))
            "facebook" -> shareToPackage(imageUri, text, subject, listOf("com.facebook.katana"))
            "messenger" -> shareToPackage(imageUri, text, subject, listOf("com.facebook.orca"))
            "twitter" -> shareToPackage(imageUri, text, subject, listOf("com.twitter.android"))
            else -> shareWithChooser(imageUri, text, subject)
        }
    }

    private fun shareToInstagramStories(imageUri: Uri, url: String): Map<String, Any> {
        val packageName = "com.instagram.android"
        if (!isPackageInstalled(packageName)) {
            return mapOf("success" to false, "error" to "app_not_installed", "package" to packageName)
        }

        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            setPackage(packageName)
            type = "image/png"
            setDataAndType(imageUri, "image/png")
            putExtra("interactive_asset_uri", imageUri)
            putExtra("content_url", url)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return startTargetIntent(intent, imageUri, packageName)
    }

    private fun shareToPackage(
        imageUri: Uri,
        text: String,
        subject: String,
        packages: List<String>
    ): Map<String, Any> {
        val packageName = packages.firstOrNull { isPackageInstalled(it) }
            ?: return mapOf("success" to false, "error" to "app_not_installed")

        val intent = baseSendIntent(imageUri, text, subject).apply {
            setPackage(packageName)
        }
        return startTargetIntent(intent, imageUri, packageName)
    }

    private fun shareWithChooser(imageUri: Uri, text: String, subject: String): Map<String, Any> {
        val intent = baseSendIntent(imageUri, text, subject)
        return try {
            startActivity(Intent.createChooser(intent, subject))
            mapOf("success" to true, "target" to "chooser")
        } catch (e: ActivityNotFoundException) {
            mapOf("success" to false, "error" to "no_activity")
        }
    }

    private fun baseSendIntent(imageUri: Uri, text: String, subject: String): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, imageUri)
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_SUBJECT, subject)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun startTargetIntent(intent: Intent, imageUri: Uri, packageName: String): Map<String, Any> {
        grantUriPermission(packageName, imageUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return try {
            startActivity(intent)
            mapOf("success" to true, "target" to packageName)
        } catch (e: ActivityNotFoundException) {
            mapOf("success" to false, "error" to "activity_not_found", "package" to packageName)
        } catch (e: SecurityException) {
            mapOf("success" to false, "error" to "security_exception", "package" to packageName)
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
