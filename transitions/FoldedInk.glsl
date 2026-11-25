// Author: gre
// License: MIT
// Description: Ink by ink, the outgoing image's tones fold over the middle of the frame into a symmetrical blot of its own colors on a pale ground; the blot changes into the incoming image's, which unfolds ink by ink, and its colors seep back slowly, light tones first
// Tags: ink, blot, symmetry, flat, palette, organic, abstract
// Preview: 0.45

// @range(0, 1) How much the ink draws away from the frame edges
uniform float margin; // = 0.7
// @range(0, 2.5) How vivid the inks are
uniform float vivid; // = 1.5

const int N = 9;
const int TAPS = 3;
const int MORE = 6;
// the images only mix between these two moments, so more of one of them can be read outside
const float FREED = 0.36;
const float CAUGHT = 0.64;
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

vec2 toned(vec4 c) {
  return vec2(luma(c.rgb), 1.0) * c.a;
}

vec3 paint(vec4 sum, vec2 stats, float z) {
  vec3 c = sum.rgb / sum.a;
  return clamp(stats.x + 1.2 * z * stats.y + (c - luma(c)) * vivid, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float turn = smoothstep(FREED, CAUGHT, progress);
  float soft = 0.035 * smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  vec2 asp = vec2(ratio, 1.0);

  // the color to fall back on where the spots of an image are all transparent
  vec3 own = (a.rgb * a.a + b.rgb * b.a) / max(a.a + b.a, 1e-4);
  vec2 sum = vec2(1e-4);
  vec2 ma = 1e-4 * vec2(luma(own), luma(own) * luma(own));
  vec2 mb = ma;
  // the spots melt the fine detail into broad blots, here and at the mirrored place
  vec4 broadA = vec4(1e-6), broadB = broadA;
  for (int i = 0; i < N; i++) {
    vec4 ca = progress < CAUGHT ? getFromColor(spot(i)) : vec4(0.0);
    vec4 cb = progress > FREED ? getToColor(spot(i)) : vec4(0.0);
    vec2 l = vec2(luma(ca.rgb), luma(cb.rgb));
    sum += vec2(ca.a, cb.a);
    ma += vec2(l.x, l.x * l.x) * ca.a;
    mb += vec2(l.y, l.y * l.y) * cb.a;
    vec2 q = (uv - spot(i)) * asp;
    vec2 m = (vec2(1.0 - uv.x, uv.y) - spot(i)) * asp;
    vec2 w = exp(-26.0 * vec2(dot(q, q), dot(m, m)));
    vec2 la = toned(ca), lb = toned(cb);
    broadA += vec4(la * w.x, la * w.y);
    broadB += vec4(lb * w.x, lb * w.y);
  }
  ma /= sum.x;
  mb /= sum.y;
  ma.y = sqrt(max(ma.y - ma.x * ma.x, 0.0)) + 0.03;
  mb.y = sqrt(max(mb.y - mb.x * mb.x, 0.0)) + 0.03;

  vec4 fineA = vec4(1e-6), fineB = fineA;
  for (int i = 0; i < TAPS; i++) {
    float n = float(i) * 2.0944 + 0.5;
    vec2 q = fold(uv + soft * vec2(cos(n), sin(n)) / asp);
    vec2 m = vec2(1.0 - q.x, q.y);
    if (progress < CAUGHT) fineA += vec4(toned(getFromColor(q)), toned(getFromColor(m)));
    if (progress > FREED) fineB += vec4(toned(getToColor(q)), toned(getToColor(m)));
  }
  if (progress < FREED || progress > CAUGHT) {
    bool late = progress > 0.5;
    vec4 more = vec4(0.0);
    for (int i = 0; i < MORE; i++) {
      float n = 2.39996 * float(i) + 1.5;
      vec2 q = fold(uv + soft * (0.35 + 0.1 * float(i)) * vec2(cos(n), sin(n)) / asp);
      vec2 m = vec2(1.0 - q.x, q.y);
      more += late ? vec4(toned(getToColor(q)), toned(getToColor(m))) : vec4(toned(getFromColor(q)), toned(getFromColor(m)));
    }
    more *= smoothstep(0.0, 0.18, late ? progress - CAUGHT : FREED - progress);
    fineA += late ? vec4(0.0) : more;
    fineB += late ? more : vec4(0.0);
  }
  float melt = 0.45 * smoothstep(0.1, 0.36, progress) * (1.0 - smoothstep(0.64, 0.9, progress));
  vec2 ya = mix(fineA.xz / fineA.yw, broadA.xz / broadA.yw, melt);
  vec2 yb = mix(fineB.xz / fineB.yw, broadB.xz / broadB.yw, melt);
  // light tones first, when the photo comes back
  float light = clamp(mix(ya.x, yb.x, turn), 0.0, 1.0);
  vec2 ys = mix((ya - ma.x) / ma.y, (yb - mb.x) / mb.y, turn);

  float x = abs(uv.x - 0.5) * ratio;
  float rim = 2.6 * margin * smoothstep(0.35, 1.05, length((2.0 * uv - 1.0) * vec2(0.95, 0.9)));
  // the two inks on top
  vec2 inks = vec2(0.0);
  float top = 1.0;
  for (int j = 0; j < 5; j++) {
    float k = float(j);
    float lag = 0.05 * k;
    float sym = smoothstep(0.06 + lag, 0.3 + lag, progress) * (1.0 - smoothstep(0.64 - lag, 0.96 - lag, progress));
    float f = mix(ys.x, min(ys.x, ys.y), sym);
    float wet = 0.12 * sin(31.0 * uv.y + 3.0 * sin(19.0 * x) + k);
    float h = f + sym * (wet + rim + 0.25) - (k - 2.5) * GAP;
    float m = j == 0 ? 1.0 : smoothstep(-0.06, 0.06, h);
    if (m > 0.0) {
      inks = vec2(top > 0.5 ? inks.y : inks.x, k);
      top = m;
    }
  }
  vec2 z = (inks - 2.0) * GAP;
  vec4 a0 = 1e-6 * vec4(own, 1.0), a1 = a0, b0 = a0, b1 = a0;
  for (int i = 0; i < N; i++) {
    if (turn < 1.0) {
      vec4 c = getFromColor(spot(i));
      vec2 d = (luma(c.rgb) - ma.x) / ma.y - z;
      vec2 w = c.a * (exp(-6.0 * d * d) + 1e-3);
      a0 += vec4(c.rgb, 1.0) * w.x;
      a1 += vec4(c.rgb, 1.0) * w.y;
    }
    if (turn > 0.0) {
      vec4 c = getToColor(spot(i));
      vec2 d = (luma(c.rgb) - mb.x) / mb.y - z;
      vec2 w = c.a * (exp(-6.0 * d * d) + 1e-3);
      b0 += vec4(c.rgb, 1.0) * w.x;
      b1 += vec4(c.rgb, 1.0) * w.y;
    }
  }
  vec3 c0 = mix(paint(a0, ma, z.x), paint(b0, mb, z.x), turn);
  vec3 c1 = mix(paint(a1, ma, z.y), paint(b1, mb, z.y), turn);
  vec3 col = mix(c0, c1, top);

  float soak = smoothstep(0.0, 0.1, progress - 0.1 * light);
  float dry = smoothstep(0.0, 0.16, progress - mix(0.84, 0.66, light));
  return vec4(mix(progress > 0.5 ? b.rgb : a.rgb, col, soak * (1.0 - dry)), mix(a.a, b.a, turn));
}
