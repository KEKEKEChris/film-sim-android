// flutter/build-android.sh sets these for an official build; a bare `flutter build apk` is a source
// build, an app of its own beside the official one, signed with the debug keys.
fun setting(name: String): String? = System.getenv(name)?.takeIf { it.isNotEmpty() }

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("androidx.core:core:1.16.0")
}

android {
    namespace = "com.kekekechris.latentimage"
    compileSdk = flutter.compileSdkVersion
    // CI installs one NDK and hands its version down, so the engine, the codecs and Gradle's own
    // CMake work all use the same toolchain. Without it, Flutter's default is used.
    ndkVersion = setting("FOTUFILM_ANDROID_NDK_VERSION") ?: flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = setting("FOTUFILM_ANDROID_APPLICATION_ID") ?: "com.kekekechris.latentimage"
        // The engine is built for android-28 (the Swift SDK's lowest), for 64-bit ARM alone.
        minSdk = 28
        ndk { abiFilters += "arm64-v8a" }
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The engine, its Swift runtime and codecs, and the films and camera profiles it reads, from
    // tools/build-android-engine.sh; build output, so outside the source tree.
    val engine = setting("FOTUFILM_ANDROID_ENGINE") ?: "../../build/android-engine"
    sourceSets["main"].jniLibs.srcDir("$engine/jniLibs")
    sourceSets["main"].assets.srcDir("$engine/assets")

    // A release keystore when one is named, so the build can go to Google Play; otherwise the
    // debug keys, so `flutter run --release` works on a phone.
    val keystore = setting("FOTUFILM_ANDROID_KEYSTORE")
    signingConfigs {
        if (keystore != null) {
            create("release") {
                storeFile = file(keystore)
                storePassword = setting("FOTUFILM_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = setting("FOTUFILM_ANDROID_KEY_ALIAS")
                keyPassword = setting("FOTUFILM_ANDROID_KEY_PASSWORD")
                    ?: setting("FOTUFILM_ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (keystore != null) "release" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
