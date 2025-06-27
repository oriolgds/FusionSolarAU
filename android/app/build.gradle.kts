import java.util.Properties
import java.io.FileInputStream


plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    // Try to load from environment variables first (for CI)
    System.getenv("KEYSTORE_PATH")?.let { path ->
        setProperty("storeFile", path)
        setProperty("storePassword", System.getenv("KEYSTORE_PASSWORD") ?: "")
        setProperty("keyAlias", System.getenv("KEY_ALIAS") ?: "")
        setProperty("keyPassword", System.getenv("KEY_PASSWORD") ?: "")
    } ?: run {
        // Fall back to local key.properties file if it exists (for local development)
        val keystorePropertiesFile = rootProject.file("key.properties")
        if (keystorePropertiesFile.exists()) {
            load(FileInputStream(keystorePropertiesFile))
        }
    }
}

android {
    namespace = "com.oriolgds.fusionsolarau"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.oriolgds.fusionsolarau"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            val storePassword = keystoreProperties.getProperty("storePassword")
            val keyAlias = keystoreProperties.getProperty("keyAlias")
            val keyPassword = keystoreProperties.getProperty("keyPassword")
            
            if (storeFilePath != null && storePassword != null && keyAlias != null && keyPassword != null) {
                keyAlias(keyAlias)
                keyPassword(keyPassword)
                storeFile = file(storeFilePath)
                storePassword(storePassword)
                enableV1Signing = true
                enableV2Signing = true
            } else {
                logger.warn("⚠️ Release signing not configured. Building with debug keys.")
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
