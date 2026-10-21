package com.gltransitions

import android.graphics.Bitmap
import android.graphics.Picture

/** Draws with the GPU (RuntimeShader needs it) into a bitmap the test can read. */
fun render(width: Int, height: Int, draw: (android.graphics.Canvas) -> Unit): Bitmap {
    val picture = Picture()
    draw(picture.beginRecording(width, height))
    picture.endRecording()
    return Bitmap.createBitmap(picture, width, height, Bitmap.Config.HARDWARE).copy(Bitmap.Config.ARGB_8888, false)
}

fun solid(color: Int, size: Int = 8): Bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).apply { eraseColor(color) }
