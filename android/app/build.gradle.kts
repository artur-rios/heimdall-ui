import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The keystore stays outside the repository: its path, passwords
// and alias come from environment variables, or from android/key.properties (git-
// ignored) which CI writes from the same secrets.
//
//   HEIMDALL_UI_KEYSTORE_PATH   storeFile      the keystore, absolute or relative to android/
//   HEIMDALL_UI_KEYSTORE_PASSWORD storePassword
//   HEIMDALL_UI_KEY_ALIAS       keyAlias
//   HEIMDALL_UI_KEY_PASSWORD    keyPassword    optional; defaults to the keystore password
//
// With none of them set the release build falls back to the debug key and warns
// loudly, so a build without secrets (a pull request, a fork) still works. Such an
// APK must never be distributed. A partial or unusable configuration fails the
// build rather than silently shipping a debug-signed APK.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(env: String, property: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(property)?.takeIf { it.isNotBlank() }

val releaseStorePath = signingValue("HEIMDALL_UI_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingValue("HEIMDALL_UI_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("HEIMDALL_UI_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("HEIMDALL_UI_KEY_PASSWORD", "keyPassword")

val releaseSigningValues = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias)
val hasReleaseSigning = releaseSigningValues.all { it != null }

if (!hasReleaseSigning && releaseSigningValues.any { it != null }) {
    throw GradleException(
        "Release signing is only partly configured. Set HEIMDALL_UI_KEYSTORE_PATH, " +
            "HEIMDALL_UI_KEYSTORE_PASSWORD and HEIMDALL_UI_KEY_ALIAS (and optionally " +
            "HEIMDALL_UI_KEY_PASSWORD), or none of them to sign with the debug key."
    )
}

android {
    namespace = "com.arturrios.heimdall_ui"
    // Ahead of Flutter's own default of 36, because flutter_secure_storage 11
    // publishes AAR metadata requiring its consumers to compile against 37.
    // compileSdk affects compilation only — minSdk and targetSdk are unchanged,
    // so this widens nothing about which devices the app runs on.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.arturrios.heimdall_ui"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val store = rootProject.file(releaseStorePath!!)
                if (!store.exists()) {
                    throw GradleException("The release keystore does not exist: ${store.path}")
                }
                storeFile = store
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword ?: releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "release" else "debug")
        }
    }
}

if (!hasReleaseSigning) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.project == project && it.name.contains("Release") }) {
            logger.warn(
                """
                |
                |==============================================================================
                |  WARNING: this release APK is signed with the DEBUG key.
                |  No release keystore is configured (HEIMDALL_UI_KEYSTORE_PATH, ...PASSWORD,
                |  HEIMDALL_UI_KEY_ALIAS, HEIMDALL_UI_KEY_PASSWORD, or android/key.properties).
                |  Do NOT distribute this APK; anyone can re-sign an app with the debug key.
                |==============================================================================
                |
                """.trimMargin()
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
