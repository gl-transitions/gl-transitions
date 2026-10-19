package com.gltransitions

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RuntimeShader
import android.graphics.Shader
import androidx.annotation.RequiresApi

/**
 * A transition as an [android.graphics.RuntimeShader], to draw on a hardware-accelerated canvas
 * (a View, a Compose `ShaderBrush(transitionShader.shader)`, a `RenderNode`…).
 *
 * The shader is compiled when this is created (it throws [IllegalArgumentException] if the
 * device's AGSL compiler rejects it); then [update] sets the images, the progress and the
 * parameters before each draw.
 */
@RequiresApi(33)
class TransitionShader(val transition: Transition) {
    val shader: RuntimeShader = RuntimeShader(transition.agsl)

    private val paint = Paint().apply { shader = this@TransitionShader.shader }

    /**
     * Sets what the next draws show: the transition from [from] to [to] at [progress] (0 to 1),
     * over an output of [width] × [height] pixels. [from], [to] and [textures] must draw their image
     * at the output size ([imageShader] makes one from a bitmap). [params] default to the
     * transition's defaults; [textures] must have each of the transition's extra images.
     */
    @JvmOverloads
    fun update(
        from: Shader,
        to: Shader,
        progress: Float,
        width: Float,
        height: Float,
        params: Map<String, ParamValue> = emptyMap(),
        textures: Map<String, Shader> = emptyMap(),
    ) {
        for (name in textures.keys) {
            require(name in transition.textures) { "${transition.name} has no texture $name" }
        }
        for (name in transition.textures) {
            require(name in textures) { "${transition.name} needs the texture $name" }
        }
        for ((name, value) in params) {
            val param = requireNotNull(transition.param(name)) { "${transition.name} has no parameter $name" }
            require(param.type == value.type) {
                "${transition.name}.$name is a ${param.type.name.lowercase()}, not a ${value.type.name.lowercase()}"
            }
        }
        shader.setInputShader("_from", from)
        shader.setInputShader("_to", to)
        for (name in transition.textures) shader.setInputShader(name, textures.getValue(name))
        shader.setFloatUniform("_resolution", width, height)
        shader.setFloatUniform("progress", progress)
        shader.setFloatUniform("ratio", width / height)
        for (param in transition.params) {
            val value = params[param.name] ?: param.default
            if (value.type.integer) shader.setIntUniform(param.name, value.ints)
            else shader.setFloatUniform(param.name, value.floats)
        }
    }

    /**
     * Draws the transition from [from] to [to] at [progress] over the whole [canvas] (or [width] ×
     * [height] from its origin), the images stretched to it. The canvas must be hardware accelerated.
     */
    @JvmOverloads
    fun draw(
        canvas: Canvas,
        from: Bitmap,
        to: Bitmap,
        progress: Float,
        params: Map<String, ParamValue> = emptyMap(),
        textures: Map<String, Bitmap> = emptyMap(),
        width: Int = canvas.width,
        height: Int = canvas.height,
    ) {
        update(
            images.get("_from", from, width, height),
            images.get("_to", to, width, height),
            progress,
            width.toFloat(),
            height.toFloat(),
            params,
            if (textures.isEmpty()) emptyMap() else textures.mapValues { (name, bitmap) -> images.get(name, bitmap, width, height) },
        )
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    // The image shaders of the last draw, reused while the bitmap and the size stay the same.
    private val images = ImageShaders()

    private class ImageShaders {
        private class Entry(val bitmap: Bitmap, val width: Int, val height: Int, val shader: BitmapShader)

        private val entries = HashMap<String, Entry>()

        fun get(input: String, bitmap: Bitmap, width: Int, height: Int): BitmapShader {
            val entry = entries[input]
            if (entry != null && entry.bitmap === bitmap && entry.width == width && entry.height == height) {
                return entry.shader
            }
            return imageShader(bitmap, width, height).also { entries[input] = Entry(bitmap, width, height, it) }
        }
    }

    companion object {
        /** The bitmap stretched to [width] × [height], sampled linearly and clamped to its edges. */
        @JvmStatic
        fun imageShader(bitmap: Bitmap, width: Int, height: Int): BitmapShader =
            BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
                filterMode = BitmapShader.FILTER_MODE_LINEAR
                setLocalMatrix(Matrix().apply { setScale(width.toFloat() / bitmap.width, height.toFloat() / bitmap.height) })
            }
    }
}
