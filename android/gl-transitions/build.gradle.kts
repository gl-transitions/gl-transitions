plugins {
    id("com.android.library")
}

android {
    namespace = "com.gltransitions"
    compileSdk = 36

    defaultConfig {
        // The catalog works anywhere; drawing (RuntimeShader) needs Android 13.
        minSdk = 21
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // CheckTest writes its renders with TestStorage: Gradle copies them to build/outputs.
        testInstrumentationRunnerArguments["useTestStorageService"] = "true"
    }

    // The input images of scripts/android-library/check.mjs.
    sourceSets {
        getByName("androidTest") { assets.directories.add("build/check-images") }
    }
}

dependencies {
    implementation("androidx.annotation:annotation:1.9.1")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.services:storage:1.5.0")
    androidTestUtil("androidx.test.services:test-services:1.5.0")
}
