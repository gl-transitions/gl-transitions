// Author: gre
// License: MIT
// Description: The outgoing image is cut in quick beats like a sheet under a guillotine, each piece cut again across its longer side at its own uneven point and pushed apart into floating cards, then the cards flip over one by one to the incoming image and the cuts close back in reverse order
// Tags: split, cut, recursive, rhythm, flip, cards

// @range(0, 0.1) Width of the first cut's gap, in frame heights (each following cut opens a narrower one)
uniform float gap; // = 0.05
// @range(0, 1) Darkness of the shadows the cards cast
uniform float shadow; // = 0.5
// @color Color seen between the cards
uniform vec4 background; // = vec4(0.8, 0.8, 0.78, 1.0)

const int LEVELS = 5;
const float CUT = 0.08;
const float FLIP = 0.12;
const float CLOSE = 0.06;
const float PERSPECTIVE = 0.6;

float hash(float n) {
  vec3 p = fract(vec3(n) * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

// ease-out-back so each cut lands with a small kick; then the gap closes with an ease-in
float opening(float t, float l) {
  float u = clamp((t - 0.03 - l * 0.07) / CUT, 0.0, 1.0) - 1.0;
  float c = clamp((t - 0.77 - (float(LEVELS - 1) - l) * 0.04) / CLOSE, 0.0, 1.0);
  return (1.0 + 2.4 * u * u * u + 1.4 * u * u) * (1.0 - c * c);
}

// columns: (lo.x, lo.y, hi.x), (hi.y, offset.x, offset.y), (coverage, distance to a gap, leaf index)
mat3 descend(vec2 p, float t, float aa) {
  vec2 lo = vec2(0.0), hi = vec2(ratio, 1.0), off = vec2(0.0);
  float node = 1.0, cov = 1.0, edge = 1.0, g = gap;
  for (int l = 0; l < LEVELS; l++) {
    vec2 size = hi - lo;
    vec2 ax = size.x > size.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    float cut = dot(lo + (0.32 + 0.36 * hash(node)) * size, ax);
    float s = g * opening(t, float(l));
    float d = dot(p - off, ax) - cut;
    float side = step(0.0, d);
    float dg = abs(d) - 0.5 * s;
    float fade = clamp(s / aa, 0.0, 1.0);
    cov = min(cov, mix(1.0, clamp(0.5 + dg / aa, 0.0, 1.0), fade));
    edge = min(edge, dg + 1.0 - fade);
    off += ax * (side - 0.5) * s;
    lo = mix(lo, lo * (1.0 - ax) + cut * ax, side);
    hi = mix(hi * (1.0 - ax) + cut * ax, hi, side);
    node = 2.0 * node + side;
    g *= 0.8;
  }
  return mat3(lo, hi.x, hi.y, off, cov, edge, node);
}

// a turn in [0, 1]: the leaves flip in the reverse order of the tree
float turn(float node, float t) {
  float n = exp2(float(LEVELS));
  float u = clamp((t - 0.4 - 0.26 * (2.0 * n - 1.0 - node) / (n - 1.0)) / FLIP, 0.0, 1.0);
  return u * u * (3.0 - 2.0 * u);
}

// card seen at p: (x, y in [-1, 1] on the card, cosine of its turn, coverage)
vec4 cardPoint(vec2 p, mat3 m, float t, float aa) {
  vec2 lo = m[0].xy, hi = vec2(m[0].z, m[1].x);
  vec2 hs = 0.5 * (hi - lo);
  vec2 q = p - 0.5 * (lo + hi) - m[1].yz;
  bool alongX = hs.x > hs.y;
  vec2 lq = alongX ? q : q.yx;
  vec2 lh = alongX ? hs : hs.yx;
  float a = 3.14159265 * turn(m[2].z, t);
  float c = cos(a), s = sin(a);
  // shrunk by 1 - lh.x * k so its near edge never grows past its own cell
  float k = PERSPECTIVE * s;
  float m0 = 1.0 - lh.x * k;
  float den = c * m0 - lq.x * k;
  float x = lq.x / (abs(den) < 1e-6 ? 1e-6 : den);
  float w = (1.0 + x * k) / m0;
  vec2 l = vec2(x, lq.y * w) / lh;
  vec2 e = (1.0 - abs(l)) * lh * vec2(abs(c), 1.0) / w;
  // eased in with the turn so a resting card's edges stay those of its cell
  float vis = mix(1.0, clamp(0.5 + min(e.x, e.y) / aa, 0.0, 1.0), min(20.0 * s, 1.0));
  return vec4(alongX ? l : l.yx, c, vis);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 p = uv * vec2(ratio, 1.0);
  float aa = 1.0 / 300.0;
  mat3 m = descend(p, t, aa);
  vec4 cp = cardPoint(p, m, t, aa);
  float cov = m[2].x * cp.w;
  vec2 lo = m[0].xy, hi = vec2(m[0].z, m[1].x);
  vec2 c = 0.5 * (lo + hi), h = 0.5 * (hi - lo);
  bool back = cp.z < 0.0;
  vec2 lp = back ? (h.x > h.y ? vec2(-cp.x, cp.y) : vec2(cp.x, -cp.y)) : cp.xy;
  vec2 src = clamp((c + clamp(lp, -1.0, 1.0) * h) / vec2(ratio, 1.0), 0.0, 1.0);
  vec4 card = back ? getToColor(src) : getFromColor(src);

  float lift = smoothstep(0.02, 0.18, t) * (1.0 - smoothstep(0.72, 0.99, t));
  float bevel = lift * (1.0 - smoothstep(0.0, 0.005, m[2].y));
  card.rgb = mix(card.rgb, card.rgb * 0.7 + 0.3, 0.5 * bevel);
  card.rgb *= 0.55 + 0.45 * abs(cp.z);

  vec2 sp = p + vec2(-0.012, 0.018) * lift;
  mat3 ms = descend(sp, t, 0.03);
  float sh = ms[2].x * cardPoint(sp, ms, t, 0.03).w;
  vec4 bg = background;
  bg.rgb *= 1.0 - shadow * sh * lift;
  return mix(bg, card, cov);
}
