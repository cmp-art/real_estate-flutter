// Google Services plugin — required by firebase_messaging
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Suppress "source/target value 8 is obsolete" warnings produced by third-party
    // Flutter plugins that still declare -source 8 / -target 8 in their own build files.
    // These are cosmetic warnings from dependency code — they don't affect the build output.
    afterEvaluate {
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.addAll(listOf(
                "-Xlint:-options",      // suppress "source/target 8 obsolete"
                "-Xlint:-deprecation",  // suppress deprecation notes from plugins
                "-Xlint:-unchecked"     // suppress unchecked cast notes from plugins
            ))
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}