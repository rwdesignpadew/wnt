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

    configurations.configureEach {
        resolutionStrategy.force(
            "androidx.datastore:datastore:1.2.1",
            "androidx.datastore:datastore-android:1.2.1",
            "androidx.datastore:datastore-core:1.2.1",
            "androidx.datastore:datastore-core-android:1.2.1",
            "androidx.datastore:datastore-guava:1.2.1",
            "androidx.datastore:datastore-preferences:1.2.1",
            "androidx.datastore:datastore-preferences-android:1.2.1",
        )
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
