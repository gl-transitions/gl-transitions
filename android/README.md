# gl-transitions for Android

The [gl-transitions](https://gl-transitions.com) collection for Android: 100+ transitions between two images as AGSL shaders ([`RuntimeShader`](https://developer.android.com/reference/android/graphics/RuntimeShader), Android 13+), with their metadata and typed parameters. Kotlin, usable from Java.

## Drawing a transition

```kotlin
import com.gltransitions.GLTransitions
import com.gltransitions.ParamValue
import com.gltransitions.TransitionShader

val shader = TransitionShader(GLTransitions.named("directionalwarp")!!) // compiles it

// In a View's onDraw (hardware accelerated), the bitmaps stretched to the canvas:
shader.draw(canvas, fromBitmap, toBitmap, progress, params = mapOf("direction" to ParamValue.vec2(1f, 0f)))
```

`draw` sets the images, the progress and the parameters, then fills the canvas. For other uses, `update(from, to, progress, width, height, params, textures)` takes any `Shader`s drawing the images at the output size (`TransitionShader.imageShader(bitmap, width, height)` makes one) and `shader.shader` is the `RuntimeShader` to put in a `Paint`, or in Jetpack Compose:

```kotlin
val transition = remember { TransitionShader(GLTransitions.named("cube")!!) }
Canvas(Modifier.fillMaxSize()) {
    val (w, h) = size.width.toInt() to size.height.toInt()
    transition.update(TransitionShader.imageShader(from, w, h), TransitionShader.imageShader(to, w, h), progress, size.width, size.height)
    drawRect(ShaderBrush(transition.shader))
}
```

Transitions with extra images (`transition.textures`, e.g. `luma`) take them in `textures`. Parameters are checked against the transition (`IllegalArgumentException`).

## The collection

`GLTransitions.all` lists the transitions, `GLTransitions.named(name)` finds one; this part works on any Android version. Each `Transition` has its `name`, `author`, `license`, `description`, `tags`, `params` (type, default, range, whether it is a color), extra `textures` and its AGSL source (`agsl`), whose contract is the [SkSL one of the npm package](https://github.com/gl-transitions/gl-transitions/tree/master/packages/gl-transitions#sksl-contract).

`GLTransitions.CATALOG_VERSION` is the version of the [gl-transitions npm package](https://www.npmjs.com/package/gl-transitions) the transitions come from. In CI, every transition is rendered with this library on an Android emulator and compared with the GLSL reference renders.

## Development

This library is built in the [gl-transitions repository](https://github.com/gl-transitions/gl-transitions): its catalog and AGSL sources are generated from the npm package build and not committed. JDK 17 and the Android SDK are needed.

```sh
# From the repository root
pnpm install && pnpm run build && pnpm run build:android
cd android && ./gradlew :gl-transitions:testDebugUnitTest
./gradlew :gl-transitions:connectedDebugAndroidTest   # on a device or emulator, Android 13+

# Compare every transition with the GLSL reference renders (on the connected device)
node scripts/rendering/render-references.mjs --out /tmp/refs
node scripts/android-library/check.mjs /tmp/refs
```

Each transition keeps the license of its source (`license`): MIT for nearly all of them, BSD for a few, whose notices and conditions the library ships (`com/gltransitions/LICENSES.md` in its resources).
