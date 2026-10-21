package com.gltransitions.example

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.gltransitions.GLTransitions
import com.gltransitions.Param
import com.gltransitions.ParamType
import com.gltransitions.ParamValue
import com.gltransitions.Transition
import kotlin.math.abs
import kotlin.math.max

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val images = listOf("1.jpg", "2.jpg", "3.jpg").map { name -> assets.open(name).use(BitmapFactory::decodeStream) }
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(Modifier.fillMaxSize()) { App(images) }
            }
        }
    }
}

// Each image stays for HOLD seconds, then the transition to the next one plays for TRANSITION seconds.
private const val HOLD = 1f
private const val TRANSITION = 1.5f

@Composable
fun App(images: List<Bitmap>) {
    var name by rememberSaveable { mutableStateOf("crosswarp") }
    val transition = GLTransitions.named(name) ?: GLTransitions.all.first()
    val params = remember(transition) { mutableStateMapOf<String, ParamValue>() }
    val textures = remember(transition) { transition.textures.associateWith { lumaTexture } }
    var playing by rememberSaveable { mutableStateOf(true) }
    // Seconds into the current image's cycle. Read at draw time (and by the slider) only, so
    // playing doesn't recompose the app.
    var time by rememberSaveable { mutableFloatStateOf(0f) }
    var image by rememberSaveable { mutableIntStateOf(0) }
    val progress = { ((time - HOLD) / TRANSITION).coerceIn(0f, 1f) }

    LaunchedEffect(playing) {
        if (!playing) return@LaunchedEffect
        var last = withFrameNanos { it }
        while (true) {
            val now = withFrameNanos { it }
            // A long gap (the app in the background) resumes where it was.
            time += ((now - last) / 1e9f).coerceAtMost(0.1f)
            last = now
            if (time >= HOLD + TRANSITION) {
                time -= HOLD + TRANSITION
                image = (image + 1) % images.size
            }
        }
    }

    val preview = @Composable { modifier: Modifier ->
        TransitionPreview(
            transition,
            images[image],
            images[(image + 1) % images.size],
            progress,
            modifier.aspectRatio(images[0].width.toFloat() / images[0].height).testTag("preview"),
            params.toMap(),
            textures,
        )
    }
    val details = @Composable { modifier: Modifier ->
        Column(modifier) {
            Column(Modifier.padding(12.dp)) {
                Text(transition.name, Modifier.testTag("title"), style = MaterialTheme.typography.titleLarge)
                Text(
                    listOfNotNull("by ${transition.authorName}", transition.license, transition.description).joinToString(" · "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                PlaybackControls(playing, { playing = !playing }, progress) {
                    time = HOLD + it * TRANSITION
                    playing = false
                }
                for (param in transition.params) {
                    ParamControl(param, params[param.name] ?: param.default) { params[param.name] = it }
                }
            }
            TransitionList(transition, Modifier.weight(1f)) { name = it.name }
        }
    }
    BoxWithConstraints(Modifier.safeDrawingPadding()) {
        if (maxWidth > maxHeight) {
            Row {
                preview(Modifier.weight(1f).align(Alignment.CenterVertically))
                details(Modifier.weight(1f))
            }
        } else {
            Column {
                preview(Modifier.fillMaxWidth())
                details(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun PlaybackControls(playing: Boolean, onToggle: () -> Unit, progress: () -> Float, onSeek: (Float) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        TextButton(onToggle) { Text(if (playing) "Pause" else "Play") }
        Slider(progress(), onSeek, Modifier.weight(1f))
    }
}

@Composable
private fun ParamControl(param: Param, value: ParamValue, onChange: (ParamValue) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(param.name, Modifier.width(120.dp), style = MaterialTheme.typography.bodyMedium)
        when (param.type) {
            ParamType.FLOAT -> {
                val v = value.floats()[0]
                val range = range(param, v)
                val steps = param.step?.let { max(0, ((range.endInclusive - range.start) / it).toInt() - 1) } ?: 0
                Slider(v, { onChange(ParamValue.float(it)) }, Modifier.weight(1f), valueRange = range, steps = steps)
            }
            ParamType.INT -> {
                val v = value.ints()[0]
                val range = range(param, v.toFloat())
                Slider(
                    v.toFloat(),
                    { onChange(ParamValue.int(Math.round(it))) },
                    Modifier.weight(1f),
                    valueRange = range,
                    steps = max(0, (range.endInclusive - range.start).toInt() - 1),
                )
            }
            ParamType.BOOL -> Switch(value.ints()[0] != 0, { onChange(ParamValue.bool(it)) })
            else -> Text(
                value.toString(),
                style = MaterialTheme.typography.bodySmall,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// The declared range, or one around the default (wide enough for the values of int "enums").
private fun range(param: Param, value: Float): ClosedFloatingPointRange<Float> {
    val default = if (param.type == ParamType.INT) param.default.ints()[0].toFloat() else param.default.floats()[0]
    val span = max(abs(default) * 2, if (param.type == ParamType.INT) 10f else 1f)
    val min = param.min ?: if (default >= 0) 0f else -span
    val max = param.max ?: span
    return minOf(min, value)..maxOf(max, value)
}

@Composable
private fun TransitionList(selected: Transition, modifier: Modifier, onSelect: (Transition) -> Unit) {
    val state = rememberLazyListState(GLTransitions.all.indexOf(selected))
    LazyColumn(modifier.testTag("transitions"), state) {
        items(GLTransitions.all, key = { it.name }) { transition ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(transition) }
                    .background(if (transition == selected) MaterialTheme.colorScheme.secondaryContainer else Color.Transparent)
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(transition.name)
                Text(transition.authorName, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

// Without the email some authors give.
private val Transition.authorName get() = author.substringBefore(" <")

// The extra image of the transitions that take one (luma, displacement…): a grayscale spiral.
val lumaTexture: Bitmap by lazy {
    val size = 256
    val pixels = IntArray(size * size) { i ->
        val x = (i % size) / (size - 1f) - 0.5f
        val y = (i / size) / (size - 1f) - 0.5f
        val angle = (kotlin.math.atan2(y, x) / (2 * Math.PI).toFloat() + 0.5f)
        val radius = kotlin.math.sqrt(x * x + y * y) * 1.4f
        val g = (((angle + radius * 3f) % 1f) * 255).toInt()
        android.graphics.Color.rgb(g, g, g)
    }
    Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
}
