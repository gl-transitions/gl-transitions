// Author: gre
// License: MIT
// Description: A narrow neck travels down the frame like a ring slipped along a sheet: the outgoing image is pinched into an hourglass and squeezed through it, shaded like a tube where it narrows, and the incoming image swells back to full width above the neck
// Tags: distort, squeeze, vertical, shadow

// @range(0.3, 0.97) How narrow the neck gets, as a fraction of the frame width
uniform float depth; // = 0.88
// @range(0.05, 0.5) Height of the pinched region, in frame heights
uniform float neck; // = 0.2
// @color Color seen beside the neck
uniform vec4 background; // = vec4(0.09, 0.09, 0.11, 1.0)

vec2 mirrorUv(vec2 uv) { return 1.0 - abs(1.0 - mod(uv, 2.0)); }

vec4 transition(vec2 uv) {
  float t = progress;
  float nk = clamp(neck, 0.05, 0.5);
  float e = mix(t, t * t * (3.0 - 2.0 * t), 0.6);
  // just enough margin that the picture change at the neck starts above and ends below the frame
  float margin = 0.6 * nk;
  float dy = (uv.y - mix(1.0 + margin, -margin, e)) / nk;
  float env = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.75, 1.0, t));
  float pinch = clamp(depth, 0.3, 0.97) * env * exp(-dy * dy);
  float w = 1.0 - pinch;
  float x = (uv.x - 0.5) / w;

  // the sheet is drawn into the neck, so content beside it stretches along y
  vec2 q = mirrorUv(vec2(x + 0.5, uv.y + 0.25 * nk * dy * pinch));
  vec4 c = mix(getFromColor(q), getToColor(q), smoothstep(-0.15, 0.15, dy));

  float across = sqrt(max(1.0 - 4.0 * x * x, 0.0));
  // kept at least a few pixels wide on screen in a tight neck
  float sx = (x + 0.17) / max(0.07, 0.004 / w);
  c.rgb = c.rgb * mix(1.0, 0.35 + 0.65 * across, pinch) + 0.3 * pinch * exp(-sx * sx);

  float inside = 1.0 - smoothstep(0.5, 0.5 + 0.003 / w, abs(x));
  vec4 bg = background;
  bg.rgb *= mix(0.55, 1.0, clamp((abs(uv.x - 0.5) - 0.5 * w) / 0.06, 0.0, 1.0));
  return mix(bg, c, inside);
}
