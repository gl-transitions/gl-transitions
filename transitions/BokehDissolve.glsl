// Author: gre
// License: MIT
// Description: The image falls out of focus like a camera lens, its highlights swelling into large bright bokeh discs, and the incoming image sharpens back out of its own bokeh
// Tags: blur, bokeh, lens, dissolve, light

// @range(0.01, 0.15) Radius of the bokeh discs at the peak, in frame heights
uniform float radius; // = 0.05
// @range(0, 9) Number of aperture blades, which shape the discs into polygons (below 3: round)
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
float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// how much a pixel is a highlight: none below the threshold, full at white
float highlight(vec4 c, float t) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  // nothing is brighter than white, so a threshold of 1 makes no highlights
  if (t >= 1.0) return 0.0;
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
  // the highlights weigh more as they swell, so they read as bright discs
  float boost = 12.0 * intensity * k;

  // fewer than 3 blades: a round aperture
  float n = blades >= 3 ? float(blades) : 0.0;
  float sector = n > 0.0 ? 2.0 * PI / n : 1.0;
  float apothem = cos(0.5 * sector);

  // per-pixel stratification of the taps over the disc, so its edge stays crisp
  vec2 cell = floor(uv * vec2(ratio, 1.0) * 997.0);
  float spin = 2.0 * PI * hash12(cell);
  float jitter = hash12(cell + 17.0);

  // each image is only read while it shows
  bool useFrom = w < 1.0;
  bool useTo = w > 0.0;
  // premultiplied, weighted sums of each image, and the light of their highlights,
  // starting with the pixel itself
  vec4 s0 = vec4(0.0);
  vec4 s1 = vec4(0.0);
  float t0 = 0.0;
  float t1 = 0.0;
  vec3 l0 = vec3(0.0);
  vec3 l1 = vec3(0.0);
  if (useFrom) {
    vec4 c = getFromColor(uv);
    float h = highlight(c, threshold);
    float wt = 1.0 + boost * h;
    s0 = wt * vec4(c.rgb * c.a, c.a);
    t0 = wt;
    l0 = h * c.rgb;
  }
  if (useTo) {
    vec4 c = getToColor(uv);
    float h = highlight(c, threshold);
    float wt = 1.0 + boost * h;
    s1 = wt * vec4(c.rgb * c.a, c.a);
    t1 = wt;
    l1 = h * c.rgb;
  }
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
    if (useFrom) {
      vec4 c = getFromColor(st);
      float h = highlight(c, threshold);
      float wt = 1.0 + boost * h;
      s0 += wt * vec4(c.rgb * c.a, c.a);
      t0 += wt;
      l0 += h * c.rgb;
    }
    if (useTo) {
      vec4 c = getToColor(st);
      float h = highlight(c, threshold);
      float wt = 1.0 + boost * h;
      s1 += wt * vec4(c.rgb * c.a, c.a);
      t1 += wt;
      l1 += h * c.rgb;
    }
  }
  vec4 b = mix(useFrom ? s0 / t0 : vec4(0.0), useTo ? s1 / t1 : vec4(0.0), w);
  if (b.a <= 0.0) {
    return vec4(0.0);
  }
  vec3 rgb = b.rgb / b.a;
  // the discs glow: light lifts the color, never the alpha
  vec3 light = mix(l0, l1, w) * (intensity * k * 4.0 / float(TAPS + 1));
  rgb = 1.0 - (1.0 - clamp(rgb, 0.0, 1.0)) * exp(-light);
  return vec4(rgb, b.a);
}
