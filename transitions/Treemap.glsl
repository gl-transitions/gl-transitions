// Author: gre
// License: MIT
// Description: Thin gutters split the outgoing picture into a treemap of tiles; in each tile a block of the incoming picture grows in from one side and squeezes the old one out while the tile borders slide into a new layout, until the incoming picture fills every tile and the gutters close
// Tags: grid, layout, split, squeeze, graphic

// @range(0, 0.03) Width of the gutters between the tiles at their widest, in frame heights
uniform float gutter; // = 0.016
// @color Color of the gutters
uniform vec4 gutterColor; // = vec4(0.97, 0.96, 0.93, 1.0)

const int LEVELS = 3;

float hash(float n) {
  vec3 p = fract(vec3(n) * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

float ease(float t) {
  t = clamp(t, 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 p = uv * vec2(ratio, 1.0);
  vec2 lo = vec2(0.0), hi = vec2(ratio, 1.0);
  vec2 lo0 = lo, hi0 = hi, lo1 = lo, hi1 = hi;
  float node = 1.0;
  float edge = 1e3;
  float alongX = ratio >= 1.0 ? 0.0 : 1.0;
  for (int l = 0; l < LEVELS; l++) {
    alongX = 1.0 - alongX;
    vec2 ax = vec2(alongX, 1.0 - alongX);
    float r0 = 0.22 + 0.56 * hash(node);
    float r1 = 0.22 + 0.56 * hash(node + 71.0);
    float k = 0.02 + 0.18 * hash(node + 13.0);
    float r = mix(r0, r1, ease((t - k) / 0.78));
    float c = dot(mix(lo, hi, r), ax);
    float c0 = dot(mix(lo0, hi0, r0), ax);
    float c1 = dot(mix(lo1, hi1, r1), ax);
    float d = dot(p, ax) - c;
    edge = min(edge, abs(d));
    if (d < 0.0) {
      hi = mix(hi, vec2(c), ax);
      hi0 = mix(hi0, vec2(c0), ax);
      hi1 = mix(hi1, vec2(c1), ax);
      node = 2.0 * node;
    } else {
      lo = mix(lo, vec2(c), ax);
      lo0 = mix(lo0, vec2(c0), ax);
      lo1 = mix(lo1, vec2(c1), ax);
      node = 2.0 * node + 1.0;
    }
  }
  alongX = 1.0 - alongX;
  vec2 ax = vec2(alongX, 1.0 - alongX);
  float start = 0.06 + 0.075 * mod(5.0 * node, 8.0);
  float s = ease((t - start) / 0.3);
  float flip = step(0.5, hash(node + 31.0));
  vec2 q = (p - lo) / (hi - lo);
  float a = dot(q, ax);
  a = mix(a, 1.0 - a, flip);
  float d = a - (1.0 - s);
  edge = min(edge, abs(d) * dot(hi - lo, ax));
  float af = a / max(1.0 - s, 1e-4);
  float at = (a - 1.0 + s) / max(s, 1e-4);
  af = mix(af, 1.0 - af, flip);
  at = mix(at, 1.0 - at, flip);
  vec2 qf = mix(q, vec2(af), ax);
  vec2 qt = mix(q, vec2(at), ax);
  vec4 c = d < 0.0 ? getFromColor((lo0 + qf * (hi0 - lo0)) / vec2(ratio, 1.0))
                   : getToColor((lo1 + qt * (hi1 - lo1)) / vec2(ratio, 1.0));
  float env = ease(t / 0.2) * ease((1.0 - t) / 0.2);
  float g = 0.5 * gutter * env;
  float aa = 0.0025;
  float m = smoothstep(g - aa, g + aa, edge) + 1.0 - smoothstep(0.0, aa, g);
  return mix(gutterColor, c, clamp(m, 0.0, 1.0));
}
