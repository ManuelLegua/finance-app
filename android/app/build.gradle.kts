import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Credenciales de firma de release. Viven en `android/key.properties`, que
// `android/.gitignore` excluye junto con la keystore: **nada de esto se
// commitea**. El formato está en `key.properties.ejemplo`.
//
// Si el archivo no existe —una máquina recién clonada, o alguien que solo
// quiere compilar— el build no falla: cae a la firma de depuración, igual que
// antes. Lo que sí falla es subir eso a Play Store, que es justamente lo que
// tiene que pasar.
val archivoDeFirma = rootProject.file("key.properties")
val propiedadesDeFirma = Properties().apply {
    if (archivoDeFirma.exists()) {
        FileInputStream(archivoDeFirma).use { load(it) }
    }
}
val hayFirmaPropia = archivoDeFirma.exists()

android {
    namespace = "io.github.manuellegua.finanzas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.manuellegua.finanzas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaPropia) {
            create("release") {
                keyAlias = propiedadesDeFirma.getProperty("keyAlias")
                keyPassword = propiedadesDeFirma.getProperty("keyPassword")
                storeFile = propiedadesDeFirma.getProperty("storeFile")
                    ?.let { rootProject.file(it) }
                storePassword = propiedadesDeFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayFirmaPropia) {
                signingConfigs.getByName("release")
            } else {
                // Sirve para instalar y probar; Play Store lo rechaza.
                signingConfigs.getByName("debug")
            }
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
