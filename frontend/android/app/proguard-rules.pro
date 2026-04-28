# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# RevenueCat
-keep class com.revenuecat.** { *; }

# Supabase
-keep class io.supabase.** { *; }

# Agora RTC SDK
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Gson (usado por várias libs)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }

# Firebase Crashlytics — mantém stack traces legíveis
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-renamesourcefileattribute SourceFile

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# OkHttp / Ktor
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# flutter_inappwebview — WebView para Screening Room
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**

# better_player_plus — ExoPlayer com DRM Widevine para Disney+/Netflix/Amazon
-keep class com.jhomlala.better_player.** { *; }
-dontwarn com.jhomlala.better_player.**

# ExoPlayer (usado pelo better_player_plus para DRM Widevine L1/L3)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Widevine CDM — manter classes nativas de DRM
-keep class android.media.MediaDrm { *; }
-keep class android.media.MediaDrmException { *; }
-keep class android.media.NotProvisionedException { *; }
-keep class android.media.DeniedByServerException { *; }
-keep interface android.media.MediaDrm$OnEventListener { *; }
-keep interface android.media.MediaDrm$OnKeyStatusChangeListener { *; }
-dontwarn android.media.MediaDrm**

# Suprime avisos de libs de terceiros
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
