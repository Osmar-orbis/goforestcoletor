<<<<<<< HEAD
// Caminho: android/build.gradle.kts (VERSÃO FINAL E CORRIGIDA)

=======
>>>>>>> 4a417961fe82a356c07fc6beddd78da5e80e7dc1
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
<<<<<<< HEAD
        // =================================================================
        // === A ÚNICA MUDANÇA NECESSÁRIA ESTÁ AQUI ===
        // Atualizamos a versão do Android Gradle Plugin para 8.2.2, que corrige o bug.
        classpath("com.android.tools.build:gradle:8.3.0")
        // =================================================================

        // O resto permanece exatamente como estava.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10")
        classpath("com.google.gms:google-services:4.4.1")
=======
        classpath("com.android.tools.build:gradle:7.3.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")
        classpath("com.google.gms:google-services:4.4.2")
>>>>>>> 4a417961fe82a356c07fc6beddd78da5e80e7dc1
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
<<<<<<< HEAD
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    project(":device_info_plus") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "1.8"
            }
        }
    }
    project(":flutter_archive") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "1.8"
            }
        }
    }
    project(":image_gallery_saver") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "1.8"
            }
        }
    }
    project(":media_scanner") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "1.8"
            }
        }
    }
    project(":shared_preferences_android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "11"
            }
        }
    }
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("1.9.10")
            }
        }
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
=======
}
>>>>>>> 4a417961fe82a356c07fc6beddd78da5e80e7dc1
