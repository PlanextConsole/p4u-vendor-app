allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val externalBuildDir = System.getenv("P4U_ANDROID_BUILD_DIR")?.trim().orEmpty()
val newBuildDir: Directory =
    if (externalBuildDir.isNotEmpty()) {
        rootProject.layout.dir(
            rootProject.provider { rootProject.file(externalBuildDir) },
        ).get()
    } else {
        rootProject.layout.buildDirectory
            .dir("../../build")
            .get()
    }
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
