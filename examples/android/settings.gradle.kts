pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "gl-transitions-android-example"
include(":app")

// The library from this repository instead of Maven Central: com.gl-transitions:gl-transitions
// resolves to android/gl-transitions.
includeBuild("../../android")
