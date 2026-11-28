import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Mapping/native-symbol uploads are release-publishing side effects, not APK
// compilation requirements. Keep local and device builds deterministic and
// opt in from the store/CI pipeline with -PuploadCrashlyticsSymbols=true.
val uploadCrashlyticsSymbols = providers.gradleProperty(
    "uploadCrashlyticsSymbols",
).map(String::toBoolean).orElse(false)

val signingPropertiesPath = providers.environmentVariable(
    "SILARAH_SIGNING_PROPERTIES",
).orElse(
    providers.systemProperty("user.home").map {
        "$it/.silarah/release-signing/key.properties"
    },
)
val signingPropertiesFile = file(signingPropertiesPath.get())
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}
val isReleaseInvocation = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun requiredSigningProperty(name: String): String {
    val value = signingProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException(
            "Missing Android release signing property '$name' in " +
                signingPropertiesFile.absolutePath,
        )
    }
    return value
}

android {
    namespace = "com.silarah.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (incoming-call notification) uses
        // java.time on every supported Android version.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.silarah.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (signingPropertiesFile.exists()) {
                storeFile = file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
            } else if (isReleaseInvocation) {
                throw GradleException(
                    "Android release signing configuration is missing. Expected " +
                        signingPropertiesFile.absolutePath,
                )
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            configure<CrashlyticsExtension> {
                mappingFileUploadEnabled = uploadCrashlyticsSymbols.get()
                nativeSymbolUploadEnabled = uploadCrashlyticsSymbols.get()
            }
        }
    }
}

tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Fails when the production build is unsigned or uses the debug keystore."
    doLast {
        val release = android.signingConfigs.getByName("release")
        val debug = android.signingConfigs.getByName("debug")
        val releaseStore = release.storeFile?.canonicalFile
            ?: throw GradleException("Release keystore is not configured.")
        val debugStore = debug.storeFile?.canonicalFile
        if (!releaseStore.isFile) {
            throw GradleException("Release keystore does not exist: $releaseStore")
        }
        if (debugStore != null && releaseStore == debugStore) {
            throw GradleException("Production artifacts must never use the debug keystore.")
        }
        if (release.keyAlias.isNullOrBlank()) {
            throw GradleException("Release key alias is not configured.")
        }
    }
}

tasks.matching {
    it.name == "bundleRelease" || it.name == "assembleRelease"
}.configureEach {
    dependsOn("verifyReleaseSigning")
}

// Flutter's generated registry includes the dev-only integration_test plugin
// whenever integration_test is present in pubspec. That Android implementation
// is intentionally absent from release dependencies. Keep the complete
// generated registry, but remove only that one generated registration block
// immediately before release Java compilation. Deleting the whole registry
// breaks every production plugin at runtime.
val sanitizeReleasePluginRegistrant = tasks.register("sanitizeReleasePluginRegistrant") {
    doLast {
        val registrant = layout.projectDirectory.file(
            "src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
        ).asFile
        if (!registrant.isFile) {
            throw GradleException(
                "Flutter did not generate GeneratedPluginRegistrant.java.",
            )
        }

        val source = registrant.readText()
        val integrationTestBlock = Regex(
            """(?ms)\R    try \{\R      flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\R    \} catch \(Exception e\) \{\R      Log\.e\(TAG, \"Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\", e\);\R    \}""",
        )
        val sanitized = source.replace(integrationTestBlock, "")
        if (sanitized.contains("IntegrationTestPlugin") ||
            sanitized.contains("plugin integration_test")) {
            throw GradleException(
                "Could not remove the dev-only integration_test registration.",
            )
        }
        registrant.writeText(sanitized)
    }
}

tasks.matching { it.name == "compileReleaseJavaWithJavac" }.configureEach {
    dependsOn(sanitizeReleasePluginRegistrant)
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // WindowCompat.enableEdgeToEdge (MainActivity) first shipped in 1.17.0.
    implementation("androidx.core:core:1.17.0")
}

flutter {
    source = "../.."
}
