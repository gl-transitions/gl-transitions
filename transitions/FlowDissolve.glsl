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

vec3 eddy(vec2 c) {
  vec3 h = hash(c + 47.0 * seed);
  return vec3((c + 0.5 + 0.4 * (h.xy - 0.5)) * CELL, (h.z < 0.5 ? -1.0 : 1.0) * (0.7 + 0.6 * abs(h.z - 0.5)));
}

// three eddies of a row of cells: their x, their y, their strength
mat3 eddies(vec2 c) {
  vec3 l = eddy(c - vec2(1.0, 0.0));
  vec3 m = eddy(c);
  vec3 r = eddy(c + vec2(1.0, 0.0));
  return mat3(l.x, m.x, r.x, l.y, m.y, r.y, l.z, m.z, r.z);
}

vec2 stir(vec2 x, mat3 e) {
  vec3 rx = x.x - e[0];
  vec3 ry = x.y - e[1];
  vec3 g = e[2] * exp(-(rx * rx + ry * ry) / (R * R));
  return vec2(-dot(g, ry), dot(g, rx));
}

// one Gaussian vortex per cell: its spin falls off with radius, so a line crossing it is wound into a spiral.
// the nine around x are kept from one step to the next, which seldom changes cell
vec2 flow(vec2 x, vec2 drift, inout vec2 cell, inout mat3 e0, inout mat3 e1, inout mat3 e2) {
  vec2 c = floor(x / CELL);
  if (c != cell) {
    cell = c;
    e0 = eddies(c - vec2(0.0, 1.0));
    e1 = eddies(c);
    e2 = eddies(c + vec2(0.0, 1.0));
  }
  return drift + swirl * GAMMA * (stir(x, e0) + stir(x, e1) + stir(x, e2));
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
  vec2 cell = vec2(1e5);
  mat3 e0 = mat3(0.0), e1 = mat3(0.0), e2 = mat3(0.0);
  vec2 xf = x;
  for (int i = 0; i < STEPS; i++) {
    vec2 mid = xf + 0.5 * hf * flow(xf, vec2(0.0), cell, e0, e1, e2);
    xf += hf * flow(mid, vec2(0.0), cell, e0, e1, e2);
  }
  // a straight line across the current, advected backward: the flow itself winds it into curls
  float ext = 0.5 * dot(abs(d), s) + 0.02;
  float f = mix(-ext, ext, 0.5 * (progress + e)) - dot(xf, d);
  float m = smoothstep(-0.006, 0.006, f);
  vec2 xa = x, xb = x;
  vec4 a = vec4(0.0), b = vec4(0.0);
  float wsum = 0.0;
  for (int i = 1; i <= STEPS; i++) {
    float t = float(i) / float(STEPS);
    // weighted toward the far end, the point that travelled here
    float t2 = t * t, t4 = t2 * t2;
    float w = 0.02 + t4 * t4;
    wsum += w;
    // premultiplied, so transparent texels add no color
    if (m < 1.0) {
      xa += ha * flow(xa, 0.5 * d, cell, e0, e1, e2);
      vec4 c = getFromColor(fold(xa, s));
      a += w * vec4(c.rgb * c.a, c.a);
    }
    if (m > 0.0) {
      xb += hb * flow(xb, 0.5 * d, cell, e0, e1, e2);
      vec4 c = getToColor(fold(xb, s));
      b += w * vec4(c.rgb * c.a, c.a);
    }
  }
  vec4 c = mix(a, b, m) / wsum;
  c.rgb *= 1.0 - 0.3 * (1.0 - m) * exp(-abs(f) / 0.03) * sin(PI * progress);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
