// Author: gre
// License: MIT
// Description: Both images ride one current full of eddies: a sharp front sweeps across it and is wound into curls by every eddy it crosses, the outgoing image carried downstream ahead of it while the incoming one pours in behind, until the incoming image settles sharp
// Tags: flow, fluid, organic, swirl, curl, wipe

// @param Direction of the current
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0, 1) How far the current carries the images (1: half the frame's short side)
uniform float travel; // = 0.4
// @range(0, 2) Strength of the eddies compared with the drift (0: a straight front and drift)
uniform float swirl; // = 1.0
// @param Random seed: another value gives other eddies
uniform float seed; // = 0.0

const int STEPS = 16;
const float PI = 3.141592653589793;
const float CELL = 0.5;
const float R = 0.17;
// core spin in radians per unit time: about 1.4 turns over the front's trace
const float GAMMA = 9.0;
const float FRONT_TIME = 1.12;

vec3 hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// one Gaussian vortex per cell: its spin falls off with radius, so a line crossing it is wound into a spiral
vec2 flow(vec2 x, vec2 drift) {
  vec2 q = x / CELL;
  vec2 i0 = floor(q);
  vec2 v = drift;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 c = i0 + vec2(float(i), float(j));
      vec3 h = hash(c + 47.0 * seed);
      vec2 r = (q - c - 0.5 - 0.4 * (h.xy - 0.5)) * CELL;
      float g = (h.z < 0.5 ? -1.0 : 1.0) * (0.7 + 0.6 * abs(h.z - 0.5)) * exp(-dot(r, r) / (R * R));
      v += swirl * GAMMA * g * vec2(-r.y, r.x);
    }
  }
  return v;
}

vec2 fold(vec2 p, vec2 s) {
  vec2 u = p / s + 0.5;
  return 1.0 - abs(1.0 - mod(u, 2.0));
}

vec4 transition(vec2 uv) {
  vec2 d = normalize(direction);
  vec2 s = vec2(ratio, 1.0) / min(ratio, 1.0);
  vec2 x = (uv - 0.5) * s;
  float e = progress * progress * (3.0 - 2.0 * progress);
  float ha = -travel * e / float(STEPS);
  float hb = travel * (1.0 - e) / float(STEPS);
  float hf = -FRONT_TIME / float(STEPS) * sin(PI * progress);
  vec2 xa = x, xb = x, xf = x;
  vec4 a = vec4(0.0), b = vec4(0.0);
  float wsum = 0.0;
  for (int i = 1; i <= STEPS; i++) {
    xa += ha * flow(xa, 0.5 * d);
    xb += hb * flow(xb, 0.5 * d);
    xf += hf * flow(xf + 0.5 * hf * flow(xf, vec2(0.0)), vec2(0.0));
    float t = float(i) / float(STEPS);
    // weighted toward the far end, the point that travelled here
    float t2 = t * t, t4 = t2 * t2;
    float w = 0.02 + t4 * t4;
    vec4 ca = getFromColor(fold(xa, s));
    vec4 cb = getToColor(fold(xb, s));
    // premultiplied, so transparent texels add no color
    a += w * vec4(ca.rgb * ca.a, ca.a);
    b += w * vec4(cb.rgb * cb.a, cb.a);
    wsum += w;
  }
  // a straight line across the current, advected backward: the flow itself winds it into curls
  float ext = 0.5 * dot(abs(d), s) + 0.02;
  float f = mix(-ext, ext, 0.5 * (progress + e)) - dot(xf, d);
  float m = smoothstep(-0.006, 0.006, f);
  vec4 c = mix(a, b, m) / wsum;
  c.rgb *= 1.0 - 0.3 * (1.0 - m) * exp(-abs(f) / 0.03) * sin(PI * progress);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
