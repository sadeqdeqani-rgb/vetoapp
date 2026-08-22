allprojects {
    repositories {
        // مخزن محلی Flutter engine (تحریمی)
        maven(url = "file:///home/sadeq/development/flutter_local_maven")
        maven(url = "https://maven.aliyun.com/repository/google")
        maven(url = "https://maven.aliyun.com/repository/public")
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

// jni 1.0.3 compiles Java sources that reference these Android/JVM libraries,
// but does not declare them in its Android library module.
gradle.projectsEvaluated {
    project(":jni").dependencies {
        add("implementation", "androidx.annotation:annotation:1.5.0")
        add("implementation", "org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    }
    project(":jni_flutter").dependencies {
        add("implementation", "androidx.annotation:annotation:1.5.0")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
