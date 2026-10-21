plugins {
    id("com.android.library")
    `maven-publish`
}

// The coordinates of the published library (and of the dependency examples/android substitutes).
group = "com.gl-transitions"

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

    publishing {
        singleVariant("release") {
            withSourcesJar()
            withJavadocJar()
        }
    }
}

dependencies {
    implementation("androidx.annotation:annotation:1.11.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.services:storage:1.5.0")
    androidTestUtil("androidx.test.services:test-services:1.5.0")
}

// CI publishes it to build/staging-repo with the npm package's version (-Pversion=…), then signs
// and uploads it to Maven Central (.github/workflows/ci.yml).
publishing {
    publications {
        register<MavenPublication>("release") {
            artifactId = "gl-transitions"
            afterEvaluate { from(components["release"]) }
            pom {
                name = "gl-transitions"
                description = "The gl-transitions collection for Android: transitions between two images as AGSL shaders for RuntimeShader, with their metadata and typed parameters."
                url = "https://gl-transitions.com"
                licenses {
                    license {
                        name = "MIT"
                        url = "https://opensource.org/license/mit"
                    }
                    // A few transitions: the library ships their notices (com/gltransitions/LICENSES.md).
                    license {
                        name = "BSD-3-Clause"
                        url = "https://opensource.org/license/bsd-3-clause"
                        comments = "Some transitions: see com/gltransitions/LICENSES.md in the library"
                    }
                    license {
                        name = "BSD-2-Clause"
                        url = "https://opensource.org/license/bsd-2-clause"
                        comments = "Some transitions: see com/gltransitions/LICENSES.md in the library"
                    }
                }
                developers {
                    developer {
                        id = "gre"
                        name = "Gaëtan Renaudeau"
                        url = "https://github.com/gre"
                    }
                }
                scm {
                    url = "https://github.com/gl-transitions/gl-transitions"
                    connection = "scm:git:https://github.com/gl-transitions/gl-transitions.git"
                    developerConnection = "scm:git:ssh://git@github.com/gl-transitions/gl-transitions.git"
                }
            }
        }
    }
    repositories {
        maven {
            name = "staging"
            url = uri(layout.buildDirectory.dir("staging-repo"))
        }
    }
}
