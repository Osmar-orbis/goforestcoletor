// Arquivo: android/settings.gradle.kts (VERSÃO FINAL COM ORDEM CORRIGIDA)

// Bloco 1: Gerenciamento de Plugins
// Define de onde o Gradle pode baixar os plugins da internet.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Bloco 2: Gerenciamento da Toolchain (Java)
// Permite que o Gradle baixe o JDK 17 automaticamente.
toolchainManagement {
    jvm {
        javaRepositories {
            repository("graalvm") {
                url = uri("https://api.foojay.io/disco/v3.0" )
                content {
                    include("org.graalvm.buildtools.native", "toolchain")
                }
            }
            repository("foojay") {
                url = uri("https://api.foojay.io/disco/v3.0" )
            }
        }
    }
}

// Bloco 3: Inclusão das Ferramentas do Flutter (MUITO IMPORTANTE)
// Este bloco precisa vir ANTES do bloco `plugins` para que o Gradle
// encontre os plugins locais do Flutter.
val flutterSdkPath = run {
    val properties = java.util.Properties()
    file("local.properties").inputStream().use { properties.load(it) }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
    require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
    flutterSdkPath
}

includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

// Bloco 4: Declaração de Plugins
// Agora que o Gradle já carregou as ferramentas do Flutter, ele encontrará o 'flutter-plugin-loader'.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.23" apply false
    id("com.google.gms.google-services") version "4.4.1" apply false
}

// Bloco 5: Inclusão do Módulo Principal do App
include(":app")
