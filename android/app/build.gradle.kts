// Arquivo: android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.geoforestcoletor"
    
    // ALTERE ESTA LINHA DE 34 PARA 35
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.geoforestcoletor"
        minSdk = 23
        
        // É UMA BOA PRÁTICA ALINHAR ESTA LINHA TAMBÉM
        targetSdk = 35
        
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
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
    // Esta linha também lê a variável do gradle.properties
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:${property("kotlinVersion")}")

    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.firebase:firebase-perf-ktx")
}
