group = "com.silarah.calls"
version = "1.0"

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.silarah.calls"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    implementation("androidx.core:core:1.17.0")
    // Self-managed calls: status-bar call chip, Bluetooth / car buttons,
    // hold when a regular phone call arrives (Android 8+ at runtime).
    implementation("androidx.core:core-telecom:1.1.0")
    // The call's audio engine (stream_webrtc_flutter, in the app already):
    // its audio session is ended with the call (CallTones.endCallAudio).
    compileOnly(project(":stream_webrtc_flutter"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
