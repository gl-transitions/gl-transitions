# Android example

A Jetpack Compose app (Android 13+) that plays the transitions of the [Android library](../../android) between the sample images: pick a transition, pause, scrub, tune its parameters.

- `TransitionPreview.kt`: a transition in Compose: `TransitionShader.draw` on the native canvas, the progress read at draw time (playing redraws without recomposing).
- `MainActivity.kt`: the app.

The library comes from this repository (`includeBuild("../../android")` in `settings.gradle.kts`), in place of `com.gl-transitions:gl-transitions` from Maven Central.

## Run it

```sh
# From the repository root: the npm package build, then the library's sources
pnpm install && pnpm run build && pnpm run build:android

cd examples/android
./gradlew :app:installDebug   # on a device or emulator, Android 13+
./gradlew :app:connectedDebugAndroidTest   # every transition drawn in the preview, the app started
```

JDK 17 and the Android SDK (platform 37) are needed. The **Android library** workflow builds the app and runs these tests on an emulator.
