// Author: gre
// License: MIT
// Description: Two sets of fine concentric rings, centered on two points that drift toward each other, overlay the image and interfere into a shifting moire of wide bands; the bands open onto the incoming image and widen until it fills the frame, while the thin dark and light ring lines fade away
// Tags: moire, rings, interference, pattern, graphic, reveal

// @range(10, 80) Number of rings per frame height in each set
uniform float density; // = 36.0
// @range(1, 8) How many moire bands the rings make at the start; they get fewer and wider as the centers come together
uniform float bands; // = 3.0
// @range(-1, 1) How far the two centers turn around each other, in turns
uniform float drift; // = 0.25
// @range(0, 1) Strength of the ring lines drawn over the image
uniform float lines; // = 0.5

const float PI = 3.141592653589793;
// half width of the antialiased edges, in frame heights
const float AA = 0.0012;
// half width of a ring line, in ring spacings
const float LINE = 0.1;
// widest antialiased edge of the bands, in bands, which also sets when they start and finish
// opening
const float EDGE = 0.05;
// angle of the line between the two centers at the start, in radians
const float START = 0.35;
// strength of the ring lines at lines = 1, so the image always shows through them
const float INK = 0.7;

// coverage of the ring lines at radius r, box-filtered over the antialiasing width, and
// faded to their mean coverage when the rings get too fine to resolve
float ringLines(float r, float f) {
  float q = abs(fract(r * f + 0.5) - 0.5);
  float aa = AA * f;
  float c = clamp((LINE - q) / (2.0 * aa) + 0.5, 0.0, 1.0);
  return mix(c, 2.0 * LINE, clamp(10.0 * aa - 0.5, 0.0, 1.0));
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  float t = progress * progress * (3.0 - 2.0 * progress);
  float f = max(density, 1.0);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);

  // the two centers turn around the middle of the frame and come together
  float ang = 2.0 * PI * drift * t + START;
  float k = max(bands, 1.0) * (1.0 - 0.75 * t);
  vec2 axis = vec2(cos(ang), sin(ang)) * 0.5 * k / f;
  float r1 = length(p - axis);
  float r2 = length(p + axis);
  // the second set is slightly finer than the first, which bends the bands into curves
  float f2 = f + 1.2 * k;

  // the beat of the two ring sets: wide bands where their rings line up, at this distance
  // from the middle of the nearest band, in bands
  float beat = abs(fract(f2 * r2 - f * r1 + 0.5) - 0.5);
  // the bands open from their middles and widen until they cover the frame
  // with an edge antialiased from the analytic gradient of the beat
  vec2 grad = f2 * (p + axis) / max(r2, AA) - f * (p - axis) / max(r1, AA);
  float s = min(AA * length(grad) + 0.004, EDGE);
  float w = mix(-EDGE, 0.5 + EDGE, t);
  float m = 1.0 - smoothstep(w - s, w + s, beat);

  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);

  // the thin lines of both sets, dark over the outgoing image and light over the incoming
  // one, fade in and out
  float o = INK * clamp(lines, 0.0, 1.0) * sin(PI * t);
  float l = 1.0 - (1.0 - o * ringLines(r1, f)) * (1.0 - o * ringLines(r2, f2));
  c.rgb = mix(c.rgb, vec3(c.a * m), l);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
