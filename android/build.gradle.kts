allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// receive_sharing_intent 등: Java 1.8 vs Kotlin 21 — 모두 17로 (Kotlin은 afterEvaluate 안에서)
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// DeleteFix: JVM 17 alignment for all modules
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as com.android.build.gradle.BaseExtension).compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}
// DeleteFix: compileSdk 35 floor — AGP resource linking (Base.V*.Theme.AppCompat)
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            if ((compileSdk ?: 0) < 35) {
                compileSdk = 35
            }
        }
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            val current = compileSdkVersion?.toString()
                ?.removePrefix("android-")
                ?.toIntOrNull() ?: 0
            if (current < 35) {
                compileSdkVersion(35)
            }
        }
    }
}
