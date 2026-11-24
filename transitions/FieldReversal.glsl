// Author: gre
// License: MIT
// Description: The outgoing picture combs itself into thousands of small colored needles lined up on the field between two magnetic poles; the poles wheel round half a turn, every needle swings with the field and rolls over to the incoming picture's color as it reverses, and the needles sharpen back into the incoming picture
// Tags: magnetic, field, needles, rotate, texture

// @range(12, 60) Needles across the frame's short side
uniform float needles; // = 34.0
// @range(0.8, 2) Length of a needle, in needle spacings
uniform float stretch; // = 1.6
// @range(0, 1) Shading of the needles and the sheen that travels as they turn
uniform float relief; // = 0.7

const float PI = 3.141592653589793;
const float START = 0.35;
const float POLE = 0.3;
const vec2 LIGHT = vec2(0.5547, 0.8321);

vec2 hash2(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

vec2 pole(float a) {
  return POLE * vec2(cos(a), sin(a));
}

vec2 field(vec2 x, vec2 d) {
  vec2 u = x - d, v = x + d;
  vec2 f = u / (dot(u, u) + 0.004) - v / (dot(v, v) + 0.004);
  return f / max(length(f), 1e-4);
}

// the field takes hold near the poles first, and lets go there last
float hold(vec2 x, vec2 d) {
  float far = min(length(x - d), length(x + d));
  float late = 0.08 * far / (far + 0.4);
  float y = clamp((min(progress, 1.0 - progress) - late) / 0.2, 0.0, 1.0);
  // starts at once but lands softly
  return y * (1.0 + y - y * y);
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

struct Needle {
  float rank;
  float cover;
  float side;
  float lit;
  vec2 at;
};

vec4 over(vec4 col, Needle k, vec2 s) {
  vec2 uv = clamp(k.at / s + 0.5, 0.0, 1.0);
  vec4 c = pm(k.side > 0.0 ? getFromColor(uv) : getToColor(uv));
  c.rgb *= 1.0 + k.lit;
  return mix(col, c, k.cover);
}

vec4 transition(vec2 uv) {
  vec2 s = vec2(ratio, 1.0) / min(ratio, 1.0);
  vec2 x = (uv - 0.5) * s;
  float n = max(needles, 1.0);
  float e = smoothstep(0.09, 0.91, progress);
  vec2 d0 = pole(START), d1 = pole(START + PI * (e + 0.03 * sin(2.0 * PI * e)));
  vec2 cell = floor(x * n);
  float px = 0.04 + 0.002 * n;

  // three deep: a pixel between two soft edges still has an opaque needle behind them
  Needle k1 = Needle(-1.0, 0.0, 1.0, 0.0, x), k2 = k1, k3 = k1;
  for (int j = -2; j <= 2; j++) {
    for (int i = -2; i <= 2; i++) {
      vec2 id = cell + vec2(float(i), float(j));
      vec2 h = hash2(id + 107.0);
      if (h.x <= k3.rank) continue;
      vec2 c = (id + 0.15 + 0.7 * h) / n;
      vec2 b = field(c, d1);
      vec2 d = (x - c) * n;
      float u = dot(d, b) / clamp(stretch, 0.1, 2.0);
      float v = b.x * d.y - b.y * d.x;
      if (abs(u) >= 1.0 || abs(v) >= 0.5) continue;
      float turned = dot(b, field(c, d0));
      // seen edge-on when it rolls over
      float w = 0.5 * mix(0.45, 1.0, smoothstep(0.0, 0.5, abs(turned)));
      float cov = clamp((w * sqrt(1.0 - u * u) - abs(v)) / px, 0.0, 1.0);
      if (cov <= 0.0) continue;
      float g = hold(c, d0);
      float sheen = 1.0 - dot(b, LIGHT) * dot(b, LIGHT);
      float lit = g * relief * ((0.28 * sheen * sheen + 0.1) * (1.0 - 2.0 * abs(v / w)) + 0.35 * v / w * b.x + 0.1 * u - 0.06);
      Needle k = Needle(h.x, cov, turned, lit, mix(x, c, g));
      if (h.x > k1.rank) {
        k3 = k2;
        k2 = k1;
        k1 = k;
      } else if (h.x > k2.rank) {
        k3 = k2;
        k2 = k;
      } else {
        k3 = k;
      }
    }
  }

  float g = hold(x, d0);
  vec4 col = mix(pm(getToColor(uv)), pm(getFromColor(uv)), smoothstep(-0.15, 0.15, dot(field(x, d1), field(x, d0))));
  col.rgb *= 1.0 - 0.65 * g;
  k2.lit -= 0.35 * g * relief;
  k3.lit -= 0.5 * g * relief;
  col = over(over(over(col, k3, s), k2, s), k1, s);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
