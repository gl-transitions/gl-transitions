package com.gltransitions

import android.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TransitionShaderTest {
    private val red = solid(Color.RED)
    private val blue = solid(Color.BLUE)

    private fun pixel(name: String, progress: Float, textures: Map<String, android.graphics.Bitmap> = emptyMap()): Int {
        val shader = TransitionShader(GLTransitions.named(name)!!)
        return render(8, 8) { shader.draw(it, red, blue, progress, textures = textures) }.getPixel(4, 4)
    }

    @Test
    fun everyTransitionCompiles() {
        val failures = GLTransitions.all.mapNotNull { transition ->
            runCatching { TransitionShader(transition) }.exceptionOrNull()?.let { "${transition.name}: ${it.message}" }
        }
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }

    @Test
    fun fade() {
        assertEquals(Color.RED, pixel("fade", 0f))
        assertEquals(Color.BLUE, pixel("fade", 1f))
        val half = pixel("fade", 0.5f)
        assertEquals(128f, Color.red(half).toFloat(), 1f)
        assertEquals(128f, Color.blue(half).toFloat(), 1f)
    }

    @Test
    fun textures() {
        assertThrows(IllegalArgumentException::class.java) { pixel("luma", 0.5f) }
        assertThrows(IllegalArgumentException::class.java) { pixel("fade", 0.5f, mapOf("luma" to red)) }
        // The dark parts of the mask go first.
        assertEquals(Color.BLUE, pixel("luma", 0.5f, mapOf("luma" to solid(Color.BLACK))))
        assertEquals(Color.RED, pixel("luma", 0.5f, mapOf("luma" to solid(Color.WHITE))))
    }

    @Test
    fun params() {
        val shader = TransitionShader(GLTransitions.named("cube")!!)
        val draw = { params: Map<String, ParamValue> -> render(8, 8) { shader.draw(it, red, blue, 0.5f, params) } }
        assertThrows(IllegalArgumentException::class.java) { draw(mapOf("nope" to ParamValue.float(1f))) }
        assertThrows(IllegalArgumentException::class.java) { draw(mapOf("persp" to ParamValue.int(1))) }
        draw(mapOf("persp" to ParamValue.float(0.2f)))
    }
}
