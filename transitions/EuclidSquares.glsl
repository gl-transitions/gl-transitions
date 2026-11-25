// Author: gre
// License: MIT
// Description: The outgoing image settles into a wall of flat squares, each rectangle filled with the largest squares that fit and the rest with smaller and smaller ones; as the corners glide, rows of tiny squares swell out of nothing, squares of the incoming image's colors open inside them, the smallest first, and they clear up into it
// Tags: squares, blocks, flat-color, geometric, math
// Preview: 0.6

// @range(0, 1) How far the corners of the rectangles glide
uniform float glide; // = 1.0
// @range(0, 1) How vivid the flat colors are
uniform float vividness; // = 0.6

vec4 vivid(vec4 c, float k) {
  float g = dot(c.rgb, vec3(0.333));
  return vec4(clamp(g + (c.rgb - g) * (1.0 + vividness * k), 0.0, 1.0), c.a);
}

// turns flat as k goes to 1; what stands out among the reads keeps its color vivid and steady while it moves
vec4 paint(vec2 uv, vec2 c, vec2 r, float k, bool incoming) {
  vec4 acc = vec4(0.0);
  float total = 0.0;
  r *= smoothstep(0.6, 1.0, k);
  for (int i = 0; i < 8; i++) {
    vec2 o = fract(vec2(0.754878, 0.569840) * (float(i) + 0.5)) - 0.5;
    vec2 q = mix(uv, c + o * r, k);
    vec4 t = incoming ? getToColor(q) : getFromColor(q);
    float w = 0.15 + max(t.r, max(t.g, t.b)) - min(t.r, min(t.g, t.b));
    acc += vec4(t.rgb * t.a, t.a) * w;
    total += w;
  }
  return vivid(vec4(acc.rgb / max(acc.a, 1e-5), acc.a / total), k);
}

vec4 squareAt(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  bool tall = ratio < 1.0;
  vec2 L = tall ? a.yx : a;
  vec2 P = tall ? (uv * a).yx : uv * a;
  float t = mix(0.5, progress, glide);
  float x0 = L.x * (0.5 + 0.2 * sin(3.0 * t - 0.5));
  float side = step(x0, P.x);
  vec2 org = vec2(side * x0, 0.0);
  L.x = mix(x0, L.x - x0, side);
  vec2 C = L * (0.5 + 0.36 * vec2(sin(4.2 * t - 2.4 + 2.4 * side), cos(3.3 * t - 2.6 + 2.0 * side)));
  P -= org;
  vec2 s = step(C, P);
  vec2 wh = mix(C, L - C, s);
  vec2 p = abs(mix(P, L - P, s));
  vec2 o = vec2(0.0);
  float size = 0.0;
  for (int i = 0; i < 12; i++) {
    bool wide = wh.x > wh.y;
    float m = max(min(wh.x, wh.y), 1e-3);
    float n = floor((wide ? wh.x : wh.y) / m + 1e-4);
    float k = floor((wide ? p.x - o.x : p.y - o.y) / m);
    vec2 dir = wide ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    size = m;
    o += dir * min(k, n) * m;
    if (k < n) break;
    wh -= dir * n * m;
    if (min(wh.x, wh.y) < 0.004) break;
  }
  vec2 c = o + 0.5 * size;
  vec2 loc = abs(p - c) / size;
  c = mix(c, L - c, s) + org;
  if (tall) c = c.yx;
  float big = clamp(1.0 + log2(size / 0.5) / 5.0, 0.0, 1.0);
  float open = smoothstep(0.0, 0.2, progress - 0.26 - 0.28 * big);
  bool fresh = max(loc.x, loc.y) < 0.52 * open;
  float k = fresh ? 1.0 - smoothstep(0.68, 0.98, progress) : smoothstep(0.02, 0.32, progress);
  vec4 col = paint(uv, c / a, 0.85 * size / a, k, fresh);
  return vec4(col.rgb * col.a, col.a);
}

vec4 transition(vec2 uv) {
  vec2 e = 0.0011 / vec2(ratio, 1.0) * smoothstep(0.0, 0.1, min(progress, 1.0 - progress));
  vec4 s = squareAt(uv + e * vec2(0.5, 1.0)) + squareAt(uv + e * vec2(-1.0, 0.5)) + squareAt(uv - e * vec2(0.5, 1.0)) + squareAt(uv - e * vec2(-1.0, 0.5));
  return vec4(s.rgb / max(s.a, 1e-5), 0.25 * s.a);
}
