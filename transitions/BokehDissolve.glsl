// Author: gre
// License: MIT
// Description: The image falls out of focus like a camera lens, its highlights swelling into large bright bokeh discs, and the incoming image sharpens back out of its own bokeh
// Tags: blur, bokeh, lens, dissolve, light

// @range(0.01, 0.15) Radius of the bokeh discs at the peak, in frame heights
uniform float radius; // = 0.05
// @range(0, 9) Number of aperture blades, which shape the discs into polygons (0 = round)
uniform int blades; // = 0
// @range(0, 1) Brightness above which a pixel is a highlight that swells into a disc
uniform float threshold; // = 0.7
// @range(0, 3) Brightness of the bokeh discs
uniform float intensity; // = 1.0

#define PI 3.141592653589793
const int TAPS = 16;

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// a hash of an integer cell, stable across precisions
float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// how much a pixel is a highlight: none below the threshold, full at white
float highlight(vec4 c, float t) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  float h = smoothstep(t, 1.0, lum);
  return h * h * c.a;
}

vec4 transition(vec2 uv) {
  // the lens defocuses then focuses back: 0 at both ends, 1 at the peak
  float t = 1.0 - abs(2.0 * progress - 1.0);
  float k = t * t * (3.0 - 2.0 * t);
  // the incoming image takes over while everything is out of focus
  float w = smoothstep(0.35, 0.65, progress);
  float r = radius * k;
  float th = min(threshold, 0.99);
  // the highlights weigh more as they swell, so they read as bright discs
  float boost = 12.0 * intensity * k;

  // fewer than 3 blades: a round aperture
  float n = blades >= 3 ? float(blades) : 0.0;
  float sector = n > 0.0 ? 2.0 * PI / n : 1.0;
  float apothem = cos(0.5 * sector);

  // per-pixel stratification of the taps over the disc, so its edge stays crisp
  vec2 cell = floor(uv * vec2(ratio, 1.0) * 600.0);
  float spin = 2.0 * PI * hash(cell);
  float jitter = hash(cell + 17.0);

  vec4 c0 = getFromColor(uv);
  vec4 c1 = getToColor(uv);
  // premultiplied, weighted sums of each image, and the light of their highlights
  vec4 s0 = vec4(c0.rgb * c0.a, c0.a);
  vec4 s1 = vec4(c1.rgb * c1.a, c1.a);
  float t0 = 1.0;
  float t1 = 1.0;
  vec3 l0 = vec3(0.0);
  vec3 l1 = vec3(0.0);
  for (int i = 0; i < TAPS; i++) {
    float fi = float(i);
    float a = fi * 2.39996323 + spin;
    float d = sqrt((fi + jitter) / float(TAPS));
    if (n > 0.0) {
      // the aperture's polygon: its boundary in the direction of the tap
      float s = mod(a, sector) - 0.5 * sector;
      d *= apothem / cos(s);
    }
    vec2 st = mirror(uv + r * d * vec2(cos(a) / ratio, sin(a)));
    vec4 a0 = getFromColor(st);
    vec4 a1 = getToColor(st);
    float h0 = highlight(a0, th);
    float h1 = highlight(a1, th);
    float w0 = 1.0 + boost * h0;
    float w1 = 1.0 + boost * h1;
    s0 += w0 * vec4(a0.rgb * a0.a, a0.a);
    s1 += w1 * vec4(a1.rgb * a1.a, a1.a);
    t0 += w0;
    t1 += w1;
    l0 += h0 * a0.rgb;
    l1 += h1 * a1.rgb;
  }
  vec4 b = mix(s0 / t0, s1 / t1, w);
  if (b.a <= 0.0) {
    return mix(c0, c1, w);
  }
  vec3 rgb = b.rgb / b.a;
  // the discs glow: light lifts the color, never the alpha
  vec3 light = mix(l0, l1, w) * (intensity * k * 4.0 / float(TAPS));
  rgb = 1.0 - (1.0 - clamp(rgb, 0.0, 1.0)) * exp(-light);
  return vec4(rgb, b.a);
}
