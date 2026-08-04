plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.gshabbir.multiimagecroptool"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        applicationId = "com.gshabbir.multiimagecroptool"
        minSdk = 23 // 🌟 Firebase Auth کے لیے 23 سیٹ کیا گیا ہے
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            // 🌟 ایپ کے کریش کو روکنے کے لیے ProGuard پروسیسنگ بند کی گئی ہے
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
