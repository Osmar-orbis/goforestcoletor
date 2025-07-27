// Arquivo: android/build.gradle.kts (SINTAXE KOTLIN CORRIGIDA)

// O bloco "buildscript" não existe em .kts. As dependências são definidas de forma diferente.
// Em vez disso, usamos o bloco "plugins" no settings.gradle.kts e "dependencies" aqui,
// mas para manter a estrutura o mais próximo possível, definimos no classpath de buildscript.
// A forma moderna seria usar o bloco `plugins` no `settings.gradle.kts`.
// Por enquanto, vamos manter a estrutura antiga para minimizar as alterações.

buildscript {
    val kotlinVersion by extra("1.9.23") // Define a versão do Kotlin aqui se não estiver no gradle.properties

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.0")
        // A sintaxe para acessar a propriedade kotlinVersion é diferente
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${property("kotlinVersion")}")
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// A configuração do jvmTarget já está no seu `android/app/build.gradle.kts`
// onde é mais apropriada. Podemos remover esta seção genérica para evitar conflitos.
// Se o build falhar, podemos adicioná-la de volta.

rootProject.buildDir = rootProject.file("../build")
subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
    project.evaluationDependsOn(":app")
}

// A sintaxe para registrar tasks é um pouco diferente
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
