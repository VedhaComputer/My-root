import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val appKeystorePropertiesFile = file("key.properties")
val keyProps = Properties()

val keyPropsFile = when {
    appKeystorePropertiesFile.exists() -> appKeystorePropertiesFile
    keystorePropertiesFile.exists() -> keystorePropertiesFile
    else -> null
}

if (keyPropsFile != null) {
    FileInputStream(keyPropsFile).use { keyProps.load(it) }
}

val envStoreFile = System.getenv("MYROOT_KEYSTORE_PATH") ?: keyProps.getProperty("storeFile")
val envStorePassword = System.getenv("MYROOT_KEYSTORE_PASSWORD") ?: keyProps.getProperty("storePassword")
val envKeyAlias = System.getenv("MYROOT_KEY_ALIAS") ?: keyProps.getProperty("keyAlias")
val envKeyPassword = System.getenv("MYROOT_KEY_PASSWORD") ?: keyProps.getProperty("keyPassword")

val hasProductionSigning = !envStoreFile.isNullOrBlank() &&
        !envStorePassword.isNullOrBlank() &&
        !envKeyAlias.isNullOrBlank() &&
        !envKeyPassword.isNullOrBlank()

val isExplicitLocalDebugSigning = project.findProperty("allowLocalDebugSigning") == "true" ||
        System.getenv("ALLOW_LOCAL_DEBUG_SIGNING") == "true"

val isProductionSigningEnforced = project.findProperty("enforceProductionSigning") == "true" ||
        System.getenv("ENFORCE_PRODUCTION_SIGNING") == "true"

android {
    namespace = "com.myroot.my_root"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.myroot.my_root"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasProductionSigning) {
            val storePath = envStoreFile!!
            val store = if (File(storePath).isAbsolute) File(storePath) else file(storePath)
            if (!store.exists()) {
                throw GradleException("❌ PRODUCTION SIGNING ERROR: Configured release keystore file does not exist: ${store.absolutePath}")
            }
            create("release") {
                storeFile = store
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            }
        }
    }

    buildTypes {
        release {
            when {
                hasProductionSigning && isExplicitLocalDebugSigning -> {
                    throw GradleException(
                        "❌ CONFLICTING SIGNING CONFIGURATION: Both production signing credentials and '-PallowLocalDebugSigning=true' were provided. " +
                        "To prevent signing ambiguity, remove '-PallowLocalDebugSigning' when production credentials are configured."
                    )
                }
                isExplicitLocalDebugSigning && isProductionSigningEnforced -> {
                    throw GradleException(
                        "❌ PRODUCTION CI ENFORCEMENT: Local debug signing is strictly prohibited when production signing enforcement is active (ENFORCE_PRODUCTION_SIGNING=true / -PenforceProductionSigning=true)."
                    )
                }
                hasProductionSigning -> {
                    signingConfig = signingConfigs.getByName("release")
                }
                isExplicitLocalDebugSigning -> {
                    logger.warn("⚠️ NON-PRODUCTION SIGNING: Release artifact will be signed with Android debug keystore (-PallowLocalDebugSigning=true). This artifact is strictly prohibited from production distribution.")
                    signingConfig = signingConfigs.getByName("debug")
                }
                else -> {
                    throw GradleException(
                        "❌ PRODUCTION SIGNING REQUIRED: Release build failed closed. " +
                        "Production release builds require explicitly configured signing credentials via android/key.properties " +
                        "or environment variables (MYROOT_KEYSTORE_PATH, MYROOT_KEYSTORE_PASSWORD, MYROOT_KEY_ALIAS, MYROOT_KEY_PASSWORD). " +
                        "For non-production local verification builds ONLY, explicitly pass '-PallowLocalDebugSigning=true'."
                    )
                }
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
