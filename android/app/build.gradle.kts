plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Groovy: apply plugin: 'com.google.gms.google-services'
    id("com.google.gms.google-services")
}

android {
    namespace = "com.isle.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 등이 요구하는 Java 8+ API desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    flavorDimensions += "edition"
    productFlavors {
        create("full") {
            dimension = "edition"
            applicationId = "com.isle.app"
            resValue("string", "app_name", "Isle")
        }
        create("light") {
            dimension = "edition"
            applicationId = "com.isle.app.light"
            resValue("string", "app_name", "Isle Light")
        }
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

