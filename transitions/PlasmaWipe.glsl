// Author: gre
// License: MIT
// Description: A flowing plasma of sine waves, as in the old demos, draws moving bands through which the incoming image spreads like tendrils, with a glowing edge
// Tags: wipe, plasma, organic, glow

// @range(0.5, 10) Size of the plasma: higher values make more, thinner bands
uniform float scale; // = 3.0
// @range(0, 0.5) Softness of the band edges
uniform float smoothness; // = 0.1
// @range(0, 1) How much the plasma flows during the transition (at most 1, so a revealed area never goes back)
uniform float flow; // = 1.0
// @color Color of the glow along the edges
uniform vec3 edgeColor; // = vec3(1.0, 0.45, 0.9)
// @range(0, 2) Strength of the glow along the edges
uniform float edgeStrength; // = 0.6

const float PI = 3.14159265;

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  // measured in square pixels, so the waves are not stretched
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0) * max(scale, 0.0) * 2.0 * PI;
  // the phase of the waves; the folded plasma below then changes by at most 0.9 * flow per
  // unit of progress, slower than the threshold, so the reveal never goes back
  float t = clamp(flow, 0.0, 1.0) * progress * 0.5;
  // the classic plasma: sines of x, y, a diagonal and the distance to an off-center point
  float v = sin(p.x * 0.6 + t)
    + sin(p.y * 0.8 - t * 0.8)
    + sin((p.x * 0.5 + p.y * 0.7) * 0.7 + t * 0.6)
    + sin(length(p - vec2(0.15, -0.1) * max(scale, 0.0) * 2.0 * PI) * 0.9 - t * 1.2);
  // folded into bands in [0, 1]
  v = abs(fract(v * 0.25 + 0.5) * 2.0 - 1.0);

  // the soft edge is fully below every band at the start and above every band at the end
  float s = max(smoothness, 0.001);
  float threshold = mix(-s, 1.0 + s, progress);
  // > 0 where the incoming image shows
  float m = 1.0 - smoothstep(threshold - s, threshold + s, v);

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 col = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  if (col.a <= 0.0) return vec4(0.0);
  // a light along the edge, adding nothing to the alpha
  float glow = 4.0 * m * (1.0 - m) * max(edgeStrength, 0.0);
  return vec4(col.rgb / col.a + edgeColor * glow, col.a);
}
