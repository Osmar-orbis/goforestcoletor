// Arquivo: android/app/build.gradle.kts (VERSÃO FINAL CORRIGIDA)

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.example.geoforestcoletor"
    compileSdk = 35

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                storeFile = file(keyProperties.getProperty("storeFile") ?: "")
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.geoforestcoletor"
        minSdk = 23
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // =======================================================
    // ================ CORREÇÃO APLICADA AQUI ===============
    // =======================================================
    kotlinOptions {
        jvmTarget = "1.8" // <<<<<<< MUDE AQUI PARA 17
    }

    // Esta é a "Regra de Ouro" que força tudo a usar o Java 17.
    kotlin {
        jvmToolchain(17)
    }
    // =======================================================

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.firebase:firebase-perf-ktx")
    implementation("com.google.firebase:firebase-analytics")
}