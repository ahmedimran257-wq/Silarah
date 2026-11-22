import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // google_mlkit_object_detection 0.13.x includes ML Kit's optional
    // Firebase-hosted custom-model bridge. That bridge still declares the
    // retired firebase-iid artifact, whose receiver is already provided by
    // modern firebase-messaging. Keeping both makes release builds fail with
    // a duplicate FirebaseInstanceIdReceiver. Silarah uses the bundled ML Kit
    // detector only, so remove the obsolete transitive module everywhere.
    configurations.configureEach {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }

    // Flutter plugins do not all publish the same Java bytecode target. A
    // clean runner can otherwise pair a plugin's Java 11 task with Kotlin 17
    // and fail Gradle's release validation. Preserve each Android module's
    // declared Java level and make its paired Kotlin task use the same level.
    afterEvaluate {
        // Some plugins pin a JDK installation with `jvmToolchain(N)` (thermal,
        // pulled in by Stream's call client, pins 17). Builds then fail on any
        // machine without that exact JDK installed, although Flutter's own JDK
        // compiles the code fine. Compile such modules with the JDK running
        // the build; their bytecode level still comes from the module's
        // source/target compatibility, aligned for Kotlin just below.
        val javaToolchain = extensions
            .findByType<org.gradle.api.plugins.JavaPluginExtension>()
            ?.toolchain
        if (javaToolchain?.languageVersion?.isPresent == true) {
            javaToolchain.languageVersion.set(
                org.gradle.jvm.toolchain.JavaLanguageVersion.of(
                    JavaVersion.current().majorVersion.toInt(),
                ),
            )
        }
        tasks.withType<KotlinCompile>().configureEach {
            val javaTaskName = name.replace("Kotlin", "JavaWithJavac")
            val javaTask = tasks.findByName(javaTaskName) as? JavaCompile
            if (javaTask != null) {
                compilerOptions.jvmTarget.set(
                    JvmTarget.fromTarget(javaTask.targetCompatibility),
                )
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
