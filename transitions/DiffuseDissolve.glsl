// Author: gre
// License: MIT
// Description: The outgoing image diffuses into a shimmering, grainy haze, as if its pixels were scattered further and further from where they belong, and the incoming image condenses back out of the haze as they settle into place
// Tags: dissolve, grain, noise, scatter, texture

// @range(0.01, 0.2) How far the pixels scatter at the peak, in frame heights
uniform float radius; // = 0.06
// @range(0.002, 0.02) Size of a grain, in frame heights
uniform float grainSize; // = 0.004
// @range(0, 1) How much the grains swirl around while they are scattered
uniform float shimmer; // = 0.5

const float PI = 3.14159265;

// a hash of an integer cell, stable across precisions
vec4 hash42(vec2 p) {
  vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float a = 1.0 - abs(2.0 * progress - 1.0);
  float amount = a * a * (3.0 - 2.0 * a);
  vec2 cell = floor(uv * vec2(ratio, 1.0) / max(grainSize, 1e-4));
  vec4 h = hash42(cell);
  float angle = 2.0 * PI * (h.x + shimmer * (2.0 * h.w - 1.0) * progress);
  float dist = radius * amount * 0.5 * (h.y + h.z);
  vec2 offset = dist * vec2(cos(angle) / ratio, sin(angle));
  vec2 suv = mirror(uv + offset);
  // each grain switches at its own moment around the peak (hashed off the cell corners, independently of the scatter)
  float when = 0.3 + 0.4 * hash42(cell + vec2(0.5, 0.25)).x;
  float m = smoothstep(when - 0.1, when + 0.1, progress);
  // each image is only read while it shows
  if (m <= 0.0) return getFromColor(suv);
  if (m >= 1.0) return getToColor(suv);
  return mix(getFromColor(suv), getToColor(suv), m);
}
