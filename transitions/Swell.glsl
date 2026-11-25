// Author: gre
// License: MIT
// Description: Points of light all over the outgoing image swell into flat, crisp discs of their own colors, the brightest first and on top, until it is a pile of big soft-colored confetti; the incoming image's lights swell up through them, and inside each one the sharp picture swells in turn until it fills the frame
// Tags: circle, dots, light, bokeh, graphic
// Preview: 0.45

// @range(0.04, 0.25) Radius of the biggest discs, in frame heights
uniform float radius; // = 0.11
// @range(0, 1) How much the bright points start before the dark ones
uniform float order; // = 0.6

const float AA = 0.0016;
// start of the last discs; the delays and durations below add up to 1
const float LAG = 0.24;

vec3 hash3(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xxy + q.yzz) * q.zyx);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

float bright(vec4 c) {
  float l = 0.6 * dot(c.rgb, vec3(0.299, 0.587, 0.114)) + 0.6 * max(c.r, max(c.g, c.b)) - 0.2 * min(c.r, min(c.g, c.b));
  return clamp(l, 0.0, 1.0) * c.a;
}

float ease(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

float pop(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * (2.0 - x) * mix(0.8, 1.0, x);
}

float disc(float d, float r) {
  return (1.0 - smoothstep(r - AA, r + AA, d)) * smoothstep(0.0, AA, r);
}

// lays the discs of an image over `below`, and opens them onto `inner` when they are the incoming ones
vec4 discs(vec2 p, vec4 below, vec4 inner, bool incoming) {
  float size = max(radius, 0.02) / 1.25;
  vec2 k = vec2(ratio, 1.0);
  // reaches the farthest corner of its own cell, and stays within the 3x3 cells searched
  float full = size * 1.25 - AA;
  vec2 shift = incoming ? vec2(0.5, 0.37) : vec2(0.0);
  vec2 g = p / size + shift;
  vec2 cell = floor(g);
  vec4 c1 = vec4(0.0);
  vec4 c2 = vec4(0.0);
  vec4 c3 = vec4(0.0);
  float k1 = -1.0, k2 = -1.0, k3 = -1.0, m1 = 0.0, m2 = 0.0, m3 = 0.0;
  float gaps = 1.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = cell + vec2(float(i), float(j));
      vec3 h = hash3(id + (incoming ? 170.0 : 50.0));
      vec2 c = id + 0.25 + 0.5 * h.xy;
      float d = length(g - c) * size;
      float top = full * (incoming ? 1.0 : mix(0.55, 1.0, h.z));
      if (d >= top + AA) continue;
      vec2 st = mirror((c - shift) * size / k);
      vec4 col = incoming ? getToColor(st) : getFromColor(st);
      float l = bright(col);
      float t = progress - mix(h.z, mix(1.0 - l, h.z, 0.2), order) * LAG;
      float r, w;
      if (incoming) {
        r = top * pop((t - 0.3) / 0.34);
        w = full * (1.5 * ease((t - 0.44) / 0.32) - 0.5);
      } else {
        r = top * pop(t / 0.36);
        w = -full;
      }
      float m = disc(d, r);
      if (m > 0.0) {
        gaps *= 1.0 - m;
        col = mix(vec4(col.rgb * col.a, col.a), inner, 1.0 - smoothstep(w, w + 0.5 * full, d));
        float key = l + 0.35 * h.z;
        if (key > k1) {
          c3 = c2; k3 = k2; m3 = m2;
          c2 = c1; k2 = k1; m2 = m1;
          c1 = col; k1 = key; m1 = m;
        } else if (key > k2) {
          c3 = c2; k3 = k2; m3 = m2;
          c2 = col; k2 = key; m2 = m;
        } else if (key > k3) {
          c3 = col; k3 = key; m3 = m;
        }
      }
    }
  }
  float w2 = (1.0 - m1) * m2;
  float w3 = (1.0 - m1) * (1.0 - m2) * m3;
  float s = m1 + w2 + w3;
  if (s <= 0.0) return below;
  return mix(below, (c1 * m1 + c2 * w2 + c3 * w3) / s, 1.0 - gaps);
}

vec4 transition(vec2 uv) {
  vec2 p = uv * vec2(ratio, 1.0);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  a.rgb *= a.a;
  b.rgb *= b.a;
  vec4 col = discs(p, discs(p, a, a, false), b, true);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
