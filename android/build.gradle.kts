allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val subprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Safely force compileSdk 36 on all subprojects without afterEvaluate crashes
subprojects {
    val applyCompileSdk = {
        if (project.hasProperty("android")) {
            val extension = project.extensions.findByName("android")
            try {
                val method = extension?.javaClass?.methods?.find { it.name == "setCompileSdk" && it.parameterTypes.size == 1 }
                method?.invoke(extension, 36)
            } catch (e: Exception) {
                // Ignore if method is unavailable
            }
        }
    }

    if (state.executed) {
        applyCompileSdk()
    } else {
        afterEvaluate {
            applyCompileSdk()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}