package com.gltransitions

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.services.storage.TestStorage
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Renders every transition between the images of the GLSL reference renders and writes one strip
 * per transition (`check/<name>.png` in the test outputs, one frame per progress value), laid out
 * as the references, or `check/<name>.error`. scripts/android-library/check.mjs runs it with the
 * instrumentation argument `renderStrips=true`, the input images and `progress.txt` (the
 * comma-separated progress values) in its assets, and compares the strips with the references.
 */
@RunWith(AndroidJUnit4::class)
class CheckTest {
    @Test
    fun renderStrips() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("renderStrips") == "true")
        val context = InstrumentationRegistry.getInstrumentation().context
        val progressValues = context.assets.open("check/progress.txt").bufferedReader().use { it.readText() }
            .split(",").map { it.trim() }.filter { it.isNotEmpty() }.map { it.toFloat() }
        fun image(name: String): Bitmap = context.assets.open("check/$name.png").use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inScaled = false })!!
        }
        val (from, to, extra) = listOf("from", "to", "extra").map(::image)
        val (width, height) = from.width to from.height
        val storage = TestStorage()

        for (transition in GLTransitions.all) {
            try {
                val shader = TransitionShader(transition)
                val textures = transition.textures.associateWith { extra }
                val strip = Bitmap.createBitmap(width * progressValues.size, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(strip)
                progressValues.forEachIndexed { i, progress ->
                    val frame = render(width, height) { shader.draw(it, from, to, progress, textures = textures) }
                    canvas.drawBitmap(frame, (i * width).toFloat(), 0f, null)
                }
                storage.openOutputFile("check/${transition.name}.png").use { strip.compress(Bitmap.CompressFormat.PNG, 100, it) }
            } catch (e: Exception) {
                storage.openOutputFile("check/${transition.name}.error").use { it.write("$e".toByteArray()) }
            }
        }
    }
}
