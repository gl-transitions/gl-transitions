// Author: gre
// License: MIT
// Description: Shafts of light burst from the highlights of the outgoing image and stream outward from a slowly drifting center; at their peak the incoming image takes over and its own rays shrink back into its highlights
// Tags: light, glow, rays, radial

// @param Point the rays stream away from, at the middle of the transition
uniform vec2 center; // = vec2(0.5, 0.6)
// @range(0, 0.5) How far the center drifts during the transition, from left to right
uniform float drift; // = 0.15
// @range(0, 1) Length of the rays at the peak, as a fraction of their distance to the center
uniform float reach; // = 0.6
// @range(0, 0.8) Brightness above which the image casts rays
uniform float threshold; // = 0.65
// @range(0, 4) Brightness of the rays
uniform float intensity; // = 1.5
// @color Tint of the rays, toward their ends
uniform vec3 tint; // = vec3(1.0, 0.82, 0.55)

const int TAPS = 20;
// number of shafts around the center
const float SHAFTS = 23.0;
const float PI = 3.141592653589793;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// smooth noise around the center, wrapping over a full turn (t in 0..1)
float shaftNoise(float t, float n, float seed) {
  float x = t * n;
  float i = floor(x);
  float f = x - i;
  float a = hash12(vec2(mod(i, n), seed));
  float b = hash12(vec2(mod(i + 1.0, n), seed));
  return mix(a, b, f * f * (3.0 - 2.0 * f));
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the light of a pixel (premultiplied): its color above the threshold
vec3 glow(vec4 c, float knee) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  return c.rgb * c.a * smoothstep(knee, knee + 0.2, lum);
}

// the light at a ray tap: one image, or both during the short switch
vec3 light(vec2 st, float knee, float m) {
  if (m <= 0.0) return glow(getFromColor(st), knee);
  if (m >= 1.0) return glow(getToColor(st), knee);
  return mix(glow(getFromColor(st), knee), glow(getToColor(st), knee), m);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // the rays grow on the outgoing image, and shrink back into the incoming one
  float amount = p < 0.5 ? smoothstep(0.0, 0.5, p) : 1.0 - smoothstep(0.5, 1.0, p);
  float peak = amount * amount * amount;
  float m = smoothstep(0.46, 0.54, p);
  vec4 fromColor = getFromColor(uv);
  vec4 toColor = getToColor(uv);
  if (amount <= 0.0) return m < 0.5 ? fromColor : toColor;

  // the rays stream away from a center drifting slowly across the frame
  vec2 origin = center + vec2(drift * (p - 0.5), 0.0);
  float len = reach * amount;
  // more and more of the image catches the light as the rays grow
  float knee = mix(threshold, 0.75 * threshold, peak);
  // a small shift of the taps, under their spacing, blends them into smooth shafts;
  // hashed by integer cell so that every GPU computes the same shift
  float jitter = hash12(floor(uv * vec2(ratio, 1.0) * 997.0));

  // the light gathered on the way to the center, fading with the distance it travels
  vec3 rays = vec3(0.0);
  float total = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float s = (float(i) + jitter) / float(TAPS);
    float w = exp(-2.0 * s);
    // warm white near the sources, tinted further along the rays
    vec3 hue = mix(vec3(1.0), tint, smoothstep(0.0, 0.6, s));
    rays += w * hue * light(mirror(mix(uv, origin, s * len)), knee, m);
    total += w;
  }
  // the light breaks into shafts of different strengths, slowly turning
  vec2 d = (uv - origin) * vec2(ratio, 1.0);
  // atan is undefined at the center itself
  float turn = length(d) > 1e-6 ? atan(d.y, d.x) / (2.0 * PI) + 0.5 : 0.0;
  float shafts = 0.6 * shaftNoise(fract(turn + 0.03 * p), SHAFTS, 1.0) + 0.4 * shaftNoise(fract(turn - 0.05 * p), 2.0 * SHAFTS + 1.0, 7.0);
  // merged back into a soft glow close to the center, where the shafts would meet in a point
  rays *= mix(1.0, mix(0.2, 1.6, smoothstep(0.15, 0.85, shafts)), smoothstep(0.0, 0.3, length(d)));
  rays *= intensity * amount * (1.0 + 3.0 * peak) / total;
  // compressed, so that bright areas never flatten into white
  rays = 0.9 * (1.0 - exp(-rays));

  // the image stays sharp, with a slight lift of the exposure at the peak; the rays are screened
  // on top of its colors and add nothing to its alpha
  vec4 c = mix(vec4(fromColor.rgb * fromColor.a, fromColor.a), vec4(toColor.rgb * toColor.a, toColor.a), m);
  if (c.a <= 0.0) return vec4(0.0);
  vec3 base = min(c.rgb / c.a * (1.0 + 0.2 * peak), 1.0);
  return vec4(base + rays - base * rays, c.a);
}
