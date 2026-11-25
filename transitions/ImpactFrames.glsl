// Author: gre
// License: MIT
// Description: The outgoing image takes a hit: jagged rays close in and snap it into a stark black and white ink drawing, scratched by speed lines that are redrawn on a beat; the incoming image bursts out of the center as a second drawing, in red on white, then its real colors shoot out along the same rays
// Tags: comic, ink, radial, impact, stylized, zoom
// Preview: 0.47

// @color Ink of the outgoing drawing (its alpha is its strength)
uniform vec4 ink; // = vec4(0.04, 0.03, 0.07, 1.0)
// @color Paper of both drawings (its alpha is its strength)
uniform vec4 paper; // = vec4(0.98, 0.97, 0.94, 1.0)
// @color Ink of the incoming drawing (its alpha is its strength)
uniform vec4 accent; // = vec4(0.95, 0.1, 0.16, 1.0)
// @range(0.1, 0.9) Brightness that separates ink from paper
uniform float threshold; // = 0.5
// @range(0, 1) Strength of the scratches along the rays
uniform float scratches; // = 1.0
// @range(0, 0.5) How much the images punch in toward the center
uniform float zoom; // = 0.28

const float TAU = 6.2831853;
const int TAPS = 12;

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

float lum(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

float strand(float a, float n, float seed) {
  float x = fract(a) * n;
  float i = floor(x);
  float lo = hash(mod(i, n) + seed);
  float hi = hash(mod(i + 1.0, n) + seed);
  return mix(lo, hi, smoothstep(0.3, 0.7, x - i));
}

// strands fade out where they get thinner than a few pixels
float fine(float r, float n) {
  return smoothstep(0.004, 0.016, TAU * r / n);
}

float jag(float a, float r) {
  float spike = strand(a, 23.0, 23.0);
  return 0.75 + 0.6 * spike * spike
    + mix(0.15, 0.35 * strand(a, 53.0, 5.0), fine(r, 53.0))
    + mix(0.12, 0.3 * strand(a, 190.0, 11.0), fine(r, 190.0));
}

// 1 inside a jagged star of mean radius R; slope is the change of j per unit of arc
float star(float r, float R, float j, float slope) {
  float d = (R * j - r) / sqrt(1.0 + R * R * slope * slope);
  return smoothstep(-0.0015, 0.0015, d) * smoothstep(0.0, 0.004, R);
}

float localLum(vec2 q, vec2 k, bool incoming) {
  vec2 s = vec2(0.0);
  for (int i = 0; i < TAPS; i++) {
    float t = 2.39996 * float(i);
    vec2 o = 0.16 * sqrt((float(i) + 0.5) / float(TAPS)) * vec2(cos(t), sin(t));
    vec2 st = mirror((q + o) / k + 0.5);
    vec4 c = incoming ? getToColor(st) : getFromColor(st);
    s += vec2(lum(c.rgb), 1.0) * c.a;
  }
  return s.x / max(s.y, 1e-4);
}

vec4 drawing(vec4 c, float around, float rough, vec4 dark, vec4 light) {
  float t = mix(threshold, around, 0.35);
  float x = smoothstep(t - 0.02, t + 0.02, lum(c.rgb) + 0.8 * rough);
  return vec4(mix(mix(c.rgb, dark.rgb, dark.a), mix(c.rgb, light.rgb, light.a), x), c.a);
}

float scratch(float a, float r) {
  // redrawn on a steady beat, like hand-inked frames; a step larger than the strand counts, so no strand comes back
  float seed = 257.0 * floor(progress * 12.0 + 0.5);
  float ray = 0.45 * strand(a, 240.0, seed) + 0.35 * strand(a, 97.0, seed + 7.0) + 0.2 * strand(a, 31.0, seed + 3.0);
  return scratches * (ray - 0.5) * smoothstep(0.1, 0.7, r);
}

vec4 transition(vec2 uv) {
  vec2 k = vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * k;
  float R = 0.5 * length(k);
  float r = length(p);
  float a = atan(p.y, p.x + 1e-6) / TAU;
  // jag is at least 0.75, so a star of this mean radius covers the corners
  float reach = 1.5 * R;
  float j = jag(a, r);
  float da = 0.0006 / (r + 0.01);
  float slope = (jag(a + da, r) - j) / (TAU * 0.0006);
  float inked = 1.0 - star(r, reach * (1.0 - smoothstep(0.0, 0.28, progress)), j, slope);
  float swap = star(r, reach * smoothstep(0.41, 0.6, progress), j, slope);
  float color = star(r, reach * smoothstep(0.62, 0.95, progress), j, slope);

  float rough = (inked > 0.0 && swap < 1.0) || (swap > 0.0 && color < 1.0) ? scratch(a, r / R) : 0.0;
  vec4 A = vec4(0.0);
  vec4 B = vec4(0.0);
  if (swap < 1.0) {
    vec2 q = p * (1.0 - zoom * smoothstep(0.0, 0.5, progress));
    A = getFromColor(mirror(q / k + 0.5));
    if (inked > 0.0) A = mix(A, drawing(A, localLum(q, k, false), rough, ink, paper), inked);
  }
  if (swap > 0.0) {
    vec2 q = p * (1.0 - zoom * (1.0 - smoothstep(0.4, 1.0, progress)));
    B = getToColor(mirror(q / k + 0.5));
    if (color < 1.0) B = mix(drawing(B, localLum(q, k, true), rough, accent, paper), B, color);
  }
  vec4 col = mix(vec4(A.rgb * A.a, A.a), vec4(B.rgb * B.a, B.a), swap);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
