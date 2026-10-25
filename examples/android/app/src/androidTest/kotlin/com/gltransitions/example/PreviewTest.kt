package com.gltransitions.example

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.unit.dp
import com.gltransitions.GLTransitions
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class PreviewTest {
    @get:Rule
    val compose = createComposeRule()

    private fun solid(color: Int) = Bitmap.createBitmap(32, 32, Bitmap.Config.ARGB_8888).apply { eraseColor(color) }

    // As the gl-transitions spec requires: `from` at progress 0, `to` at progress 1.
    @Test
    fun everyTransitionGoesFromTheFirstImageToTheSecond() {
        val (red, blue) = solid(Color.RED) to solid(Color.BLUE)
        var transition by mutableStateOf(GLTransitions.all.first())
        var progress by mutableStateOf(0f)
        compose.setContent {
            TransitionPreview(
                transition, red, blue, { progress },
                Modifier.size(64.dp).testTag("preview"),
                textures = transition.textures.associateWith { lumaTexture },
            )
        }
        fun center(): Int {
            compose.waitForIdle()
            val image = compose.onNodeWithTag("preview").captureToImage().asAndroidBitmap()
            return image.getPixel(image.width / 2, image.height / 2)
        }
        val wrong = GLTransitions.all.filter { t ->
            transition = t
            progress = 0f
            val start = center()
            progress = 1f
            val end = center()
            !(Color.red(start) > 200 && Color.blue(start) < 55 && Color.blue(end) > 200 && Color.red(end) < 55)
        }
        assertTrue("Not from red to blue: ${wrong.joinToString { it.name }}", wrong.isEmpty())
    }
}

class AppTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Test
    fun startsAndSwitchesTransitions() {
        // The preview plays forever: the test advances the clock itself.
        compose.mainClock.autoAdvance = false
        compose.mainClock.advanceTimeBy(500)
        compose.onNodeWithTag("preview").captureToImage()
        compose.onNodeWithTag("transitions").performScrollToNode(hasText("Cube"))
        compose.onNodeWithText("Cube").performClick()
        compose.mainClock.advanceTimeBy(100)
        compose.onNodeWithTag("title").assertTextEquals("Cube")
        compose.onNodeWithTag("preview").captureToImage()
    }
}
