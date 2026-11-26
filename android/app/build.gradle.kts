import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma estable para publicar actualizaciones que se instalen encima de la versión anterior.
// Se toma de variables de entorno (GitHub Actions) o de android/key.properties (solo local, no se sube).
// Sin llave propia (desarrollo) se usa la de depuración. Ver docs/INSTALACION.md.
val firma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) FileInputStream(archivo).use { load(it) }
}

fun datoFirma(variable: String, propiedad: String): String? =
    System.getenv(variable)?.takeIf { it.isNotBlank() } ?: firma.getProperty(propiedad)

val almacenFirma = datoFirma("CARPIAPP_KEYSTORE", "storeFile")

android {
    namespace = "mx.carpiapp.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "mx.carpiapp.app"
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
        if (almacenFirma != null) {
            create("publicacion") {
                storeFile = file(almacenFirma)
                storePassword = datoFirma("CARPIAPP_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = datoFirma("CARPIAPP_KEY_ALIAS", "keyAlias")
                keyPassword = datoFirma("CARPIAPP_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    // El lint de AGP 9 falla con Java 17 al revisar plugins (image_picker); no afecta al APK.
    lint {
        checkReleaseBuilds = false
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("publicacion") ?: signingConfigs.getByName("debug")
            // Reglas para que la optimización (R8) no rompa ML Kit (descripción de fotos).
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
