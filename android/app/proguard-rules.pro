# google_mlkit_text_recognition supports optional script-specific artifacts.
# Silarah uses the bundled Latin recognizer, so references to recognizers that
# are deliberately not packaged may be ignored during R8 analysis.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ML Kit object detection's Flutter wrapper compiles optional support for
# Firebase-hosted custom models. Silarah only invokes its bundled default
# detector, and the obsolete firebase-iid module is intentionally excluded in
# android/build.gradle.kts to avoid a duplicate receiver with Firebase
# Messaging. This unreachable optional path is the only remaining reference.
-dontwarn com.google.firebase.iid.FirebaseInstanceId

# MainActivity turns on edge-to-edge through AndroidX. Keep that helper as its
# own method: inlined, R8 would copy its API-guarded Window bar-colour calls
# (deprecated on Android 15) into MainActivity, and Play Console would then
# report Silarah's own class as calling them.
-keep class androidx.core.view.WindowCompat {
    public static void enableEdgeToEdge(android.view.Window);
}

# Voice calling. WebRTC's Java classes are reached from native code through
# JNI, which R8 cannot see; keep them whole or audio fails only in release.
-keep class org.webrtc.** { *; }
-keep class io.getstream.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**
# flutter_local_notifications stores notification details with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
