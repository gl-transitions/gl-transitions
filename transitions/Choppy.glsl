// Author: gre
// License: MIT
// Description: The outgoing picture turns out to be a reflection on open water: wind picks up and breaks it into long wavering slivers, every slope that tips over mirrors the incoming picture instead, and the water calms down on it
// Tags: water, waves, reflection, distort
// Preview: 0.45

// @range(0, 2) Height of the waves
uniform float waves; // = 1.0
// @range(0.6, 2) Length of the waves
uniform float size; // = 1.0

const int TAPS = 4;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// gradient of a value noise, with a steepness of at most 1.5
vec2 noiseSlope(vec2 p) {
  vec2 i = floor(p), f = p - i;
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0), du = 24.0 * f * f * (1.0 - f) * (1.0 - f);
  float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + 1.0);
  return du * vec2(mix(b - a, d - c, u.y), mix(c - a, d - b, u.x));
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec2 swell(vec2 w, float chop) {
  // leaning lattices, so that no crease runs along the frame
  return noiseSlope(w + vec2(0.35, 0.08) * w.yx) + chop * noiseSlope((w + vec2(-0.4, -0.1) * w.yx) * 2.1 + 5.0);
}

vec4 look(vec2 uv, float e) {
  float p = progress;
  // the water is seen at a low angle: waves shrink towards the top
  float z = 1.35 - uv.y;
  vec2 w = vec2((uv.x - 0.5) * ratio / (z + 0.1) * 3.2, -11.0 * log(z + 0.4)) / max(size, 0.1);
  // the smallest waves are too thin to draw far away
  float chop = 0.95 * smoothstep(0.2, 0.7, z);
  float t = p * 3.5;
  vec2 g = swell(w + vec2(0.4 * t, -t), chop);
  float s = g.y + swell(w * 1.17 + vec2(-0.5 * t, -0.6 * t) + 11.0, chop).y;
  vec2 o = waves * e * vec2(0.012 * g.x, 0.075 * s * (0.6 + 0.5 * z));
  // beyond the steepest slope at both ends
  float h = p - 0.5, h2 = h * h;
  float m = smoothstep(-0.1, 0.1, s + 8.6 * h + 60.0 * h * h2 * h2);
  vec4 c = mix(pm(getFromColor(mirror(uv + o))), pm(getToColor(mirror(uv + o + vec2(0.0, 0.04 * e)))), m);
  c.rgb *= 1.0 + 0.1 * e * clamp(s, -2.0, 2.0);
  return c;
}

vec4 transition(vec2 uv) {
  float e = smoothstep(0.0, 0.4, progress) * (1.0 - smoothstep(0.55, 1.0, progress));
  vec4 c = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float k = (float(i) + 0.5) / float(TAPS) - 0.5;
    c += look(uv + 0.0018 * min(6.0 * e, 1.0) * vec2(0.4 * k / ratio, k), e);
  }
  return c.a > 0.0 ? vec4(min(c.rgb / c.a, 1.0), c.a / float(TAPS)) : vec4(0.0);
}
