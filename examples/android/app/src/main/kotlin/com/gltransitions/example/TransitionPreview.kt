package com.gltransitions.example

import android.graphics.Bitmap
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import com.gltransitions.ParamValue
import com.gltransitions.Transition
import com.gltransitions.TransitionShader

/**
 * Draws [transition] from [from] to [to] at [progress], the images stretched to the composable.
 * [progress] is read at draw time: animating it redraws without recomposing.
 */
@Composable
fun TransitionPreview(
    transition: Transition,
    from: Bitmap,
    to: Bitmap,
    progress: () -> Float,
    modifier: Modifier = Modifier,
    params: Map<String, ParamValue> = emptyMap(),
    textures: Map<String, Bitmap> = emptyMap(),
) {
    val shader = remember(transition) { TransitionShader(transition) }
    Spacer(
        modifier.drawBehind {
            drawIntoCanvas {
                shader.draw(it.nativeCanvas, from, to, progress(), params, textures, size.width.toInt(), size.height.toInt())
            }
        },
    )
}
