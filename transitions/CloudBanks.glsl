// Author: gre
// License: MIT
// Description: The outgoing image's flat tones pile up into four banks of round clouds drifting past each other; puffs in the incoming image's colors well up inside each bank and swell until it has changed color, then the clouds melt into the incoming image
// Tags: clouds, layers, flat, palette, parallax, abstract
// Preview: 0.45

// @range(0, 2) How far the clouds drift
uniform float drift; // = 1.0
// @range(0, 2.5) How vivid the flat colors are
uniform float vivid; // = 1.5

const int N = 9;
const int TAPS = 10;
// between these two moments the shapes are free of both images, so the palettes of both are read instead of their shapes
const float FREED = 0.24;
const float CAUGHT = 0.76;
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

vec2 hash(vec2 p) {
  vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

// x: distance to the cloud bank; y: how much its puffs cover
vec2 bank(float n, vec2 p) {
  const float SPACING = 0.26;
  float base = 0.12 - 0.17 * n;
  float way = 2.0 * mod(n, 2.0) - 1.0;
  float x = p.x + way * drift * (progress - 0.5) * (0.5 + 0.2 * n) + 7.0;
  float cell = floor(x / SPACING);
  vec2 d = vec2(p.y - base, 1.0);
  for (int i = -2; i < 3; i++) {
    float id = cell + float(i);
    vec2 h = hash(vec2(id, 3.0 + 7.0 * n));
    float big = smoothstep(0.1, 0.9, 0.5 + 0.5 * sin(id * 1.15 + n * 2.0));
    vec2 c = vec2((id + 0.25 + 0.5 * h.x) * SPACING, base + 0.1 * big);
    float l = length(vec2(x, p.y) - c);
    float start = 0.26 + 0.05 * n + 0.1 * h.x;
    d = min(d, vec2(l - 0.1 - 0.13 * big - 0.04 * h.y, l - 0.75 * ease(start, start + 0.3, progress)));
  }
  // the last swell covers the whole frame before the incoming shapes do
  d.y += 0.004 - 1.6 * ease(0.58, 0.76, progress);
  return vec2(d.x, 1.0 - smoothstep(-0.0015, 0.0015, d.y));
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  bool late = progress > 0.5;
  float bend = smoothstep(0.0, 1.0, (late ? 0.97 - progress : progress - 0.03) / 0.31);
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

  vec2 p = (uv - 0.5) * asp / clamp(ratio / 1.4, 0.6, 1.0);
  float aa = mix(0.03, 0.0016, smoothstep(0.0, 0.5, bend));
  // the two inks on top, from the sky to the nearest bank, the darkest
  vec2 inks = vec2(4.0);
  vec2 head = vec2(smoothstep(0.38, 0.62, progress));
  float top = 1.0;
  for (int j = 0; j < 4; j++) {
    float n = float(j);
    vec2 d = bank(n, p);
    float cut = (1.5 - n) * GAP;
    float m = smoothstep(-aa, aa, mix(0.22 * (cut - y), -d.x, bend));
    if (m > 0.0) {
      inks = vec2(top > 0.5 ? inks.y : inks.x, 3.0 - n);
      head = vec2(top > 0.5 ? head.y : head.x, d.y);
      top = m;
    }
  }
  vec2 z = (inks - 2.0) * GAP;
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
