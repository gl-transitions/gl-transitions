// Author: gre
// License: MIT
// Description: A line sweeps across the frame and drags the outgoing image's pixels behind it as long streaks, which shorten as it goes and reveal the incoming image
// Tags: smear, streaks, directional, chromatic

// @param Direction in which the line sweeps
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0, 1) Length of the streaks at the middle of the sweep, as a part of the frame
uniform float stretch; // = 0.45
// @range(0, 1) Amount of RGB split along the streaks
uniform float chroma; // = 0.5
// @range(0, 0.2) Softness of the line and of the streaks' ends, as a part of the frame
uniform float softness; // = 0.03
// @range(0, 1) How much the streaks jitter, each row at its own length
uniform float jitter; // = 0.5

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

// smooth max with a compact support: exactly max(x, y) when they are k apart
float smax(float x, float y, float k) {
  float h = max(k - abs(x - y), 0.0) / k;
  return max(x, y) + h * h * k * 0.25;
}

// position s along the sweep (0 to 1 across the frame) to a frame coordinate
vec2 at(vec2 uv, float s0, float s, vec2 d, float ext) {
  return clamp(uv + d * (s - s0) * ext, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec2 d = normalize(direction + vec2(1e-6, 0.0));
  // ext: length of the frame along the sweep, in uv units
  float ext = abs(d.x) + abs(d.y);
  float s = 0.5 + dot(uv - 0.5, d) / ext;
  // rows across the streaks (about one per pixel line), in frame heights
  vec2 n = vec2(-d.y, d.x);
  float t = dot((uv - 0.5) * vec2(ratio, 1.0), n);
  float row = floor(t * 540.0);
  float clump = floor(t * 60.0);
  float rnd = 0.6 * hash(row + 17.0) + 0.4 * hash(clump + 311.0);

  float p = progress;
  float k = softness + 1e-4;
  // the line starts and ends at rest just beyond the frame, past its soft edge, so both ends are exact;
  // it enters at once and slows down a little toward the end
  float margin = k + 0.002;
  float a = mix(-margin, 1.0 + margin, mix(p, p * p * (3.0 - 2.0 * p), 0.5));

  // the streaks are longest when the line crosses the middle and vanish as it reaches the edges,
  // so they never repeat the frame's own border (often dark, or letterboxing)
  float h = clamp(4.0 * a * (1.0 - a), 0.0, 1.0);
  float len = stretch * h * (1.0 - 0.6 * jitter * rnd);
  float split = 0.02 * chroma * h;

  // ahead of the line the outgoing image is intact; behind it, each pixel repeats the pixel at the line
  vec4 fr = getFromColor(at(uv, s, smax(s, a + split, k), d, ext));
  vec4 fg = getFromColor(at(uv, s, smax(s, a, k), d, ext));
  vec4 fb = getFromColor(at(uv, s, smax(s, a - split, k), d, ext));
  vec4 streak = vec4(fr.r, fg.g, fb.b, fg.a);
  // a faint flicker along the streaks
  float behind = step(s, a);
  streak.rgb *= 1.0 + 0.06 * jitter * h * (hash(row * 3.0 + 5.0) - 0.5) * behind;

  // past the end of its streak, each row shows the incoming image as it is
  float w = smoothstep(len - k, len + k, a - s);
  return mix(streak, getToColor(uv), w);
}
