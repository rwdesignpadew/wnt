plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mapsApiKey = (project.findProperty("MAPS_API_KEY") as String?)
    ?: System.getenv("WNT_ANDROID_MAPS_API_KEY")
    ?: System.getenv("GOOGLE_MAPS_ANDROID_KEY")
    ?: System.getenv("WNT_MAPS_API_KEY")
    ?: ""

val uploadStoreFile = System.getenv("WNT_ANDROID_KEYSTORE")
val uploadStorePassword = System.getenv("WNT_ANDROID_STORE_PASSWORD")
val uploadKeyAlias = System.getenv("WNT_ANDROID_KEY_ALIAS") ?: "wnt-upload"
val uploadKeyPassword = System.getenv("WNT_ANDROID_KEY_PASSWORD")
val hasUploadSigning = !uploadStoreFile.isNullOrBlank()
    && !uploadStorePassword.isNullOrBlank()
    && !uploadKeyPassword.isNullOrBlank()
val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }

if (isReleaseBuild) {
    require(hasUploadSigning) { "Missing Android release signing configuration." }
}

require(mapsApiKey.isNotBlank()) {
    "Missing Google Maps API key. Set WNT_ANDROID_MAPS_API_KEY or Gradle property MAPS_API_KEY."
}

android {
    namespace = "pl.wnt.wnt_driver"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "pl.wnt.wodanatelefon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasUploadSigning) create("release") {
            storeFile = file(uploadStoreFile!!)
            storePassword = uploadStorePassword!!
            keyAlias = uploadKeyAlias
            keyPassword = uploadKeyPassword!!
        }
    }

    buildTypes {
        release {
            if (hasUploadSigning) signingConfig = signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
}
