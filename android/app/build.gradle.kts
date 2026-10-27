plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.freebuff.music_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.freebuff.music_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Keeps the Kotlin types that plugin JNI bindings look up by name
            // (see proguard-rules.pro). Without this, shared_preferences crashes
            // in release builds only: R8 renames kotlin.coroutines.Continuation
            // and the JNI method descriptor no longer resolves.
            proguardFiles("proguard-rules.pro")

            // Run lint in checkReleaseBuilds mode so a baseline can be created
            // once. After that, only new lint issues block the release build.
            lint {
                checkReleaseBuilds = true
            }

            // Build as debuggable so the app can read its own SharedPreferences
            // via `run-as` for quick local verification on device.
            isDebuggable = true
        }
    }

    lint {
        // Permit a debuggable release build for on-device verification.
        checkReleaseBuilds = true
        // baseline = file("lint-baseline.xml") // set once the baseline exists
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
