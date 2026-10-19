import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystore = rootProject.file("key.properties")
val releaseProperties = Properties().apply {
    if (releaseKeystore.isFile) {
        releaseKeystore.inputStream().use { load(it) }
    }
}
val releaseSigningReady =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .all { !releaseProperties.getProperty(it).isNullOrBlank() }
val requestedRelease = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true) ||
    it.contains("bundle", ignoreCase = true)
}
if (requestedRelease && !releaseSigningReady) {
    error("Signature de production absente : renseigner android/key.properties sans le committer.")
}

android {
    namespace = "fr.autoclair.autoclair_app"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        multiDexEnabled = true
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.autoclair.autoclair_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("production") {
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("production")
            }
            isDebuggable = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(
        "com.google.android.gms:play-services-mlkit-document-scanner:16.0.0",
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
