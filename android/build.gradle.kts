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
subprojects {
    project.evaluationDependsOn(":app")
}

// The opencv_dart 1.4.5 plugin hardcodes `compileSdk 33`, but its transitive
// AndroidX dependencies (fragment/activity/window) require compiling against
// API 34+. Force it up to the app's compileSdk (36). Reflection avoids needing
// the Android Gradle Plugin types on the root buildscript classpath.
subprojects {
    // Guard the registration itself: calling afterEvaluate on an
    // already-evaluated project (`:app`, forced above) throws. Only opencv_dart
    // needs the bump and it is not force-evaluated early.
    if (project.name == "opencv_dart") {
        afterEvaluate {
            project.extensions.findByName("android")?.let { android ->
                try {
                    android.javaClass
                        .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(android, 36)
                } catch (e: NoSuchMethodException) {
                    android.javaClass
                        .getMethod("compileSdkVersion", String::class.java)
                        .invoke(android, "android-36")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
