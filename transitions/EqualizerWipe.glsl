// Author: gre
// License: MIT
// Description: The incoming image rises from the bottom of the frame in vertical bars that bounce up and down like an audio equalizer, lit in segments and each topped by a floating peak cap that falls back slowly, their average level climbing until they fill the frame
// Tags: wipe, bars, music, vertical, retro

// @range(4, 48, 1) Number of bars across the frame
uniform int bars; // = 16
// @range(0, 0.6) How far the bars bounce above and below their average level, in frame heights
uniform float bounce; // = 0.3
// @range(0, 64, 1) Number of lit segments in a bar the height of the frame (0 for solid bars)
uniform int segments; // = 24
// @color Color of the peak caps (its alpha is their opacity)
uniform vec4 capColor; // = vec4(1.0, 1.0, 1.0, 1.0)

const float PI = 3.141592653589793;
// half width of the antialiased edges, in frame heights
const float AA = 0.0015;
// thickness of a peak cap and its gap above the bar, in frame heights
const float CAP = 0.012;
const float CAP_GAP = 0.008;

float hash11(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

// level of bar i (0 at the bottom of the frame, 1 at the top) at progress t: an eased average
// level climbing from below the frame to above it, plus a bounce that is zero at both ends.
// k holds the bar's own speeds and phases, lead how far it runs ahead of the others
float level(float i, vec4 k, float lead, float t, float amp) {
  t = clamp(t, 0.0, 1.0);
  float env = sin(PI * t);
  float ramp = t * t * (3.0 - 2.0 * t);
  float base = mix(-0.03, 1.04, mix(t, ramp, 0.3));
  float w = 2.0 * PI * t;
  // two sines of its own, plus a slow swell across the bars so neighbors move together a
  // little, like a spectrum
  float osc = 0.5 * sin(w * k.x + k.y) + 0.3 * sin(w * k.z + k.w) + 0.2 * sin(w * 2.2 - 0.55 * i);
  return base + amp * env * (osc + lead);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  float n = float(bars < 1 ? 1 : bars);
  float amp = max(bounce, 0.0);
  float x = uv.x * n;
  float i = min(floor(x), n - 1.0);
  float fx = x - i;
  // antialiasing across a column, in column widths
  float aaX = AA * n / ratio;

  vec4 k = vec4(
    3.0 + 1.5 * hash11(i + 3.0), 2.0 * PI * hash11(i),
    5.5 + 2.0 * hash11(i + 7.0), 2.0 * PI * hash11(i + 11.0)
  );
  float lead = 0.35 * (hash11(i + 19.0) - 0.5);
  float h = level(i, k, lead, progress, amp);
  // the peak cap: the highest recent level, held a moment then falling back faster and faster
  float peak = h;
  for (int j = 1; j < 12; j++) {
    float dt = float(j) * 0.012;
    float fall = max(dt - 0.03, 0.0);
    peak = max(peak, level(i, k, lead, progress - dt, amp) - 60.0 * fall * fall);
  }
  float capY = peak + CAP_GAP;

  // the bars stand apart in their columns, the gaps closing as the last bars reach the top. A
  // gap thinner than the antialiasing fades out instead of blurring the sides of the bar
  float open = 1.0 - smoothstep(0.72, 0.97, progress);
  float gap = 0.09 * open;
  float side = min(fx, 1.0 - fx);
  float inGap = clamp((gap - side) / (2.0 * aaX) + 0.5, 0.0, 1.0) * min(gap / aaX, 1.0);
  float barX = 1.0 - inGap;

  // incoming image in the bar
  vec4 b = getToColor(uv);
  float fill;
  float lit;
  if (segments > 0) {
    // lit segment by segment, the top one brightening as the level enters it, with dark
    // seams between them
    float segs = float(segments);
    float above = h * segs - floor(uv.y * segs);
    fill = clamp(above, 0.0, 1.0);
    lit = 1.0 - clamp(above - 1.0, 0.0, 1.0);
    float seam = abs(fract(uv.y * segs) - 0.5) * 2.0;
    float aaS = AA * segs * 2.0;
    b.rgb *= 1.0 - 0.38 * open * smoothstep(0.78 - aaS, 0.78 + aaS, seam);
  } else {
    fill = 1.0 - smoothstep(h - AA, h + AA, uv.y);
    lit = 1.0 - smoothstep(0.0, 0.04, h - uv.y);
  }
  b.rgb += 0.2 * open * lit * (1.0 - b.rgb);
  // a little rounded shading across the bar
  float across = 2.0 * fx - 1.0;
  b.rgb *= 1.0 - 0.15 * open * across * across;
  float m = barX * fill;

  // outgoing image, shaded in the gaps beside the bar and just under its cap
  vec4 a = getFromColor(uv);
  float beside = (1.0 - smoothstep(0.0, gap, gap - side)) * (1.0 - smoothstep(h - 0.01, h + 0.01, uv.y));
  float under = barX * smoothstep(capY - 0.025, capY, uv.y) * (1.0 - smoothstep(capY - AA, capY + AA, uv.y));
  a.rgb *= 1.0 - open * (0.35 * inGap * beside + 0.4 * under);

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);

  // the peak cap, faded in and out at both ends of the transition
  float cap = barX * smoothstep(capY - AA, capY + AA, uv.y) * (1.0 - smoothstep(capY + CAP - AA, capY + CAP + AA, uv.y));
  cap *= capColor.a * smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.95, 1.0, progress));
  c = mix(c, vec4(capColor.rgb, 1.0), cap);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
