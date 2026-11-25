// Author: gre
// License: MIT
// Description: The outgoing image settles into flowing bands of its flat tones; a pale and a dark disc of the incoming image's colors glide past each other, the bands parting around them and taking the incoming colors in their wake, then the bands reshape into the incoming image
// Tags: circle, flow, stripes, flat, poster, palette, abstract
// Preview: 0.45

// @range(0.5, 2) Width of the bands
uniform float lanes; // = 1.0
// @range(0.1, 0.28) Radius of the discs, in frame heights
uniform float radius; // = 0.19
// @range(0, 2.5) How vivid the flat colors are
uniform float vivid; // = 1.5

const int N = 9;
const int TAPS = 14;
// between these two moments the shapes are free of both images, so the palettes of both are read instead of their shapes
const float FREED = 0.26;
const float CAUGHT = 0.74;
// from one tone to the next, in deviations
const float GAP = 0.62;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 spot(int i) {
  return fract(vec2(0.754878, 0.569840) * float(i) + 0.4);
}

float ease(float a, float b, float x) {
  x = clamp((x - a) / (b - a), 0.0, 1.0);
  return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

// the most common color around the tone z, pushed to the lightness of that tone
vec3 paint(vec4 sum, vec2 stats, float z) {
  vec3 c = sum.rgb / sum.a;
  return clamp(stats.x + 1.2 * z * stats.y + (c - luma(c)) * vivid, 0.0, 1.0);
}

// each wake trails its disc: the upper one runs to the right, the lower one to the left
float wakeOf(float k, float u, float x, float px, float width) {
  float v = u - k + 2.0;
  v = k < 0.5 ? max(v, 0.0) : k > 3.5 ? min(v, 0.0) : v;
  float cap = width * sqrt(max(0.25 - v * v, 0.0));
  float way = k > 1.5 ? -1.0 : 1.0;
  return smoothstep(-0.002, 0.002, x - 0.06 - 0.09 * abs(k - 2.0) - way * px + cap);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  bool late = progress > 0.5;
  float bend = smoothstep(0.0, 1.0, (late ? 0.98 - progress : progress - 0.02) / 0.36);
  bend *= bend;

  vec2 asp = vec2(ratio, 1.0);
  // the color to fall back on where the spots of an image are all transparent
  vec3 own = (a.rgb * a.a + b.rgb * b.a) / max(a.a + b.a, 1e-4);
  vec2 sum = vec2(1e-4);
  vec2 ma = 1e-4 * vec2(luma(own), luma(own) * luma(own));
  vec2 mb = ma;
  vec4 broad = vec4(1e-6);
  for (int i = 0; i < N; i++) {
    vec4 ca = progress < CAUGHT ? getFromColor(spot(i)) : vec4(0.0);
    vec4 cb = progress > FREED ? getToColor(spot(i)) : vec4(0.0);
    vec2 l = vec2(luma(ca.rgb), luma(cb.rgb));
    sum += vec2(ca.a, cb.a);
    ma += vec2(l.x, l.x * l.x) * ca.a;
    mb += vec2(l.y, l.y * l.y) * cb.a;
    vec2 q = (uv - spot(i)) * asp;
    broad += vec4(vec2(l.x, 1.0) * ca.a, vec2(l.y, 1.0) * cb.a) * exp(-26.0 * dot(q, q));
  }
  ma /= sum.x;
  mb /= sum.y;
  ma.y = sqrt(max(ma.y - ma.x * ma.x, 0.0)) + 0.03;
  mb.y = sqrt(max(mb.y - mb.x * mb.x, 0.0)) + 0.03;

  vec4 here = late ? b : a;
  vec2 acc = vec2(luma(here.rgb), 1.0) * here.a;
  if (progress < FREED || progress > CAUGHT) {
    float soft = 0.045 * smoothstep(0.0, 0.2, late ? 1.0 - progress : progress);
    for (int i = 0; i < TAPS; i++) {
      float g = 2.39996 * float(i);
      vec2 q = fold(uv + soft * sqrt((float(i) + 0.5) / float(TAPS)) * vec2(cos(g), sin(g)) / asp);
      vec4 c = late ? getToColor(q) : getFromColor(q);
      acc += vec2(luma(c.rgb), 1.0) * c.a;
    }
  }
  // fine detail melts into a broad field before the shapes move, so their edges do not tear
  vec2 melted = late ? broad.zw : broad.xy;
  float y = mix(acc.x / max(acc.y, 1e-4), melted.x / melted.y, smoothstep(0.0, 0.54, bend));
  y = (y - (late ? mb.x : ma.x)) / (late ? mb.y : ma.y);

  vec2 p = (uv - 0.5) * asp;
  float width = 0.14 * lanes;
  float x = (2.0 * mix(progress, ease(0.0, 1.0, progress), 0.5) - 1.0) * (ratio + 0.5);
  float bob = 0.07 * sin(9.0 * progress);
  vec2 d1 = p - vec2(x, bob - 0.23);
  vec2 d2 = p - vec2(-x, bob + 0.23);
  float r2 = radius * radius;
  // stream function of a flow parting around both discs
  float psi = p.y + 0.02 * sin(5.0 * p.x + 6.0 * progress);
  psi -= r2 * (d1.y / max(dot(d1, d1), r2) + d2.y / max(dot(d2, d2), r2));
  float u = psi / width;
  float l1 = length(d1), l2 = length(d2);
  float inside = radius - min(l1, l2);

  float field = mix(y, GAP * u, bend);
  float k = clamp(floor(field / GAP + 2.0), 0.0, 3.0);
  vec2 z = (vec2(k, k + 1.0) - 2.0) * GAP;
  if (inside > -0.002) {
    // the rim of a disc lies between the closest lane and the disc
    z = vec2(clamp(floor(field / GAP + 2.5), 0.0, 4.0) - 2.0, l1 < l2 ? 2.0 : -2.0) * GAP;
  }
  vec2 n = z / GAP + 2.0;
  vec2 head = vec2(wakeOf(n.x, u, x, p.x, width), inside > -0.002 ? 1.0 : wakeOf(n.y, u, x, p.x, width));
  float aa = mix(0.03, 0.0016, smoothstep(0.0, 0.5, bend));
  float top = smoothstep(-aa, aa, mix(0.22, width / GAP, bend) * (field - 0.5 * (z.x + z.y)));
  top = inside > -0.002 ? smoothstep(-0.0015, 0.0015, inside) : top;
  // how much each image shows, as most places need the palette of only one
  vec2 share = vec2(1.0 - top, top);
  float showA = dot(share, 1.0 - head), showB = dot(share, head);
  vec4 a0 = 1e-6 * vec4(own, 1.0), a1 = a0, b0 = a0, b1 = a0;
  for (int i = 0; i < N; i++) {
    if (showA > 0.0) {
      vec4 c = getFromColor(spot(i));
      vec2 d = (luma(c.rgb) - ma.x) / ma.y - z;
      vec2 w = c.a * (exp(-6.0 * d * d) + 1e-3);
      a0 += vec4(c.rgb, 1.0) * w.x;
      a1 += vec4(c.rgb, 1.0) * w.y;
    }
    if (showB > 0.0) {
      vec4 c = getToColor(spot(i));
      vec2 d = (luma(c.rgb) - mb.x) / mb.y - z;
      vec2 w = c.a * (exp(-6.0 * d * d) + 1e-3);
      b0 += vec4(c.rgb, 1.0) * w.x;
      b1 += vec4(c.rgb, 1.0) * w.y;
    }
  }
  vec3 c0 = mix(paint(a0, ma, z.x), paint(b0, mb, z.x), head.x);
  vec3 c1 = mix(paint(a1, ma, z.y), paint(b1, mb, z.y), head.y);
  vec3 col = mix(c0, c1, top);

  float flatness = smoothstep(0.02, 0.2, progress) * (1.0 - smoothstep(0.8, 0.98, progress));
  return vec4(mix(here.rgb, col, flatness), mix(a.a, b.a, smoothstep(0.35, 0.65, progress)));
}
