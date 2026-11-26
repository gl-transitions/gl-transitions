// Author: gre
// License: MIT
// Description: Blow after blow lands on the outgoing picture as if pounding dough thin: each blow jolts the frame and spreads the picture outward from where it hit, the spread stays, and where it has been beaten thinnest it tears into lacy pores that stretch with it and open onto the incoming picture
// Tags: stretch, distort, impact, organic, tear, dissolve

// @range(1, 8, 1) Number of blows
uniform float blows; // = 6.0

const int N = 8;

float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float hash21(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
    mix(hash21(i + vec2(0.0, 1.0)), hash21(i + 1.0), f.x),
    f.y
  );
}

vec4 transition(vec2 uv) {
  float t = progress;
  float n = clamp(floor(blows), 1.0, float(N));
  vec2 p = vec2(uv.x * ratio, uv.y);
  float area = 1.0;
  float jolt = 0.0;
  for (int i = 0; i < N; i++) {
    float k = float(N - 1 - i);
    if (k < n) {
      float t0 = 0.06 + 0.7 * k / n;
      float s = clamp((t - t0) / 0.05, 0.0, 1.0);
      float hit = s * (1.0 + 0.5 * sin(3.14159 * s));
      jolt += s * (1.0 - s);
      vec2 c = vec2((0.2 + 0.6 * fract(0.31 + k * 0.618)) * ratio, 0.22 + 0.56 * fract(0.77 + k * 0.4142));
      float R = 0.2 + 0.1 * hash11(k * 5.7 + 2.0) + 0.3 * k / n;
      vec2 d = p - c;
      float sc = 1.0 - 0.5 * hit * exp(-dot(d, d) / (R * R));
      area *= sc * sc;
      p = c + d * sc;
    }
  }
  p.y += 0.02 * jolt;
  vec4 a = getFromColor(vec2(p.x / ratio, 1.0 - abs(1.0 - p.y)));
  vec4 b = getToColor(uv);
  // pores are hashed in the stretched coordinates, so they stretch with the dough
  float pores = 0.6 * noise(p * 22.0) + 0.4 * noise(p * 47.0 + 3.0);
  float thin = clamp((0.8 - area) * 1.6, 0.0, 1.0) + smoothstep(0.7, 1.0, t) * 1.2;
  return mix(a, b, smoothstep(pores - 0.04, pores + 0.04, thin - 0.05));
}
