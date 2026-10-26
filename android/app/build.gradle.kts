import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de assinatura da loja. android/key.properties fica fora do git
// (ver android/key.properties.exemplo). Sem ele, o release assina com a
// chave de debug so pra `flutter run --release` continuar funcionando.
val propriedadesChave = Properties()
val arquivoChave = rootProject.file("key.properties")
if (arquivoChave.exists()) {
    arquivoChave.inputStream().use { propriedadesChave.load(it) }
}

android {
    namespace = "com.controlegastos.controle_gastos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.controlegastos.controle_gastos"
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
        if (arquivoChave.exists()) {
            create("release") {
                keyAlias = propriedadesChave.getProperty("keyAlias")
                keyPassword = propriedadesChave.getProperty("keyPassword")
                storeFile = file(propriedadesChave.getProperty("storeFile"))
                storePassword = propriedadesChave.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (arquivoChave.exists()) {
                signingConfigs.getByName("release")
            } else {
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
