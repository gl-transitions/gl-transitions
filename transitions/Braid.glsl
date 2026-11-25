// Author: gre
// License: MIT
// Description: The outgoing image's tones draw out into four broad flat ribbons braided over and under each other, running across the frame; the incoming image's colors travel down them one ribbon at a time while the ground changes behind, then the braid loosens into the incoming image
// Tags: braid, ribbons, flat, poster, palette, abstract
// Preview: 0.5

// @range(0.05, 0.16) Half width of the ribbons, in frame heights
uniform float thick; // = 0.085
// @range(0, 2.5) How vivid the flat colors are
uniform float vivid; // = 1.5

const int N = 12;
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

// the most common color around the tone k, pushed to the lightness of that tone
vec3 ink(float k, vec2 stats, bool incoming, vec3 own) {
  float z = (k - 2.0) * GAP;
  vec4 sum = 1e-6 * vec4(own, 1.0);
  for (int i = 0; i < N; i++) {
    vec4 c = incoming ? getToColor(spot(i)) : getFromColor(spot(i));
    float d = (luma(c.rgb) - stats.x) / stats.y - z;
    sum += vec4(c.rgb, 1.0) * (c.a * (exp(-6.0 * d * d) + 1e-3));
  }
  vec3 c = sum.rgb / sum.a;
  return clamp(stats.x + 1.2 * z * stats.y + (c - luma(c)) * vivid, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  bool late = progress > 0.5;
  vec4 here = late ? b : a;
  float bend = late ? 1.0 - smoothstep(0.64, 0.97, progress) : smoothstep(0.03, 0.36, progress);
  bend *= bend;
  vec2 asp = vec2(ratio, 1.0);

  // the color to fall back on where the spots of an image are all transparent
  vec3 own = (a.rgb * a.a + b.rgb * b.a) / max(a.a + b.a, 1e-4);
  vec2 sum = vec2(1e-4);
  vec2 ma = 1e-4 * vec2(luma(own), luma(own) * luma(own));
  vec2 mb = ma;
  for (int i = 0; i < N; i++) {
    vec4 ca = getFromColor(spot(i));
    vec4 cb = getToColor(spot(i));
    vec2 l = vec2(luma(ca.rgb), luma(cb.rgb));
    sum += vec2(ca.a, cb.a);
    ma += vec2(l.x, l.x * l.x) * ca.a;
    mb += vec2(l.y, l.y * l.y) * cb.a;
  }
  ma /= sum.x;
  mb /= sum.y;
  ma.y = sqrt(max(ma.y - ma.x * ma.x, 0.0)) + 0.03;
  mb.y = sqrt(max(mb.y - mb.x * mb.x, 0.0)) + 0.03;

  // the image's smoothed tone, in deviations from its mean
  vec2 acc = vec2(luma(here.rgb), 1.0) * max(here.a, 1e-4);
  if (bend < 1.0) {
    float soft = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
    for (int i = 0; i < 6; i++) {
      float n = float(i) * 1.0472;
      vec2 q = fold(uv + (0.02 + 0.015 * mod(float(i), 2.0)) * soft * vec2(cos(n), sin(n)) / asp);
      vec4 c = late ? getToColor(q) : getFromColor(q);
      acc += vec2(luma(c.rgb), 1.0) * c.a;
    }
  }
  float y = (acc.x / acc.y - (late ? mb.x : ma.x)) / (late ? mb.y : ma.y);

  vec2 p = (uv - 0.5) * asp;
  float aa = mix(0.012, 0.0025, bend);
  float go = mix(progress, ease(0.0, 1.0, progress), 0.4);
  vec2 q = vec2(p.x * 0.985 + p.y * 0.17, p.y * 0.985 - p.x * 0.17);
  float th = 3.0 * q.x - 8.0 * go;

  // how much of each ink shows, of each image; the lightest one is the ground
  vec4 showA = vec4(0.0), showB = showA;
  float turn = ease(0.3, 0.7, progress);
  float change = smoothstep(-0.002, 0.002, turn * (ratio + 1.0) * 0.5 - length(p) * 0.9 - 0.02);
  vec2 ground = vec2(1.0 - change, change);
  float top = -9.0;
  for (int k = 0; k < 4; k++) {
    float f = float(k);
    float ph = th + 1.5708 * f;
    float away = q.y - 0.3 * sin(ph);
    float dy = 0.9 * cos(ph);
    float s = max(thick - abs(away) / sqrt(1.0 + dy * dy), -0.11);
    // nested tones stack darkest on top, ribbons by their place in the braid
    float z = mix(-f, sin(2.0 * ph + 0.5), smoothstep(0.05, 0.5, bend));
    if (z > top) {
      float field = mix(0.22 * ((f - 2.0) * GAP + 0.31 - y), s, bend);
      float cover = smoothstep(-aa, aa, field);
      float rim = smoothstep(-aa, aa, field + 0.012 * bend) * bend;
      float run = ease(0.3 + 0.05 * f, 0.62 + 0.05 * f, progress);
      float off = sqrt(max(thick * thick - away * away, 0.0));
      float head = smoothstep(-0.002, 0.002, mix(-1.0, 1.0, run) * (0.5 * ratio + 0.4) - q.x + off);
      vec2 both = vec2(1.0 - head, head);
      vec4 mine = step(abs(vec4(0.0, 1.0, 2.0, 3.0) - f), vec4(0.5));
      float keep = (1.0 - rim) * (1.0 - cover);
      ground = ground * keep + both * rim * (1.0 - cover);
      showA = showA * keep + mine * (cover * both.x);
      showB = showB * keep + mine * (cover * both.y);
      // the gap around a ribbon hides the ones below too
      if (field > -0.012 * smoothstep(0.8, 1.0, bend)) top = z;
    }
  }

  vec3 col = vec3(0.0);
  for (int k = 0; k < 5; k++) {
    vec4 one = step(abs(vec4(0.0, 1.0, 2.0, 3.0) - float(k)), vec4(0.5));
    vec2 w = k == 4 ? ground : vec2(dot(one, showA), dot(one, showB));
    if (w.x > 0.0) col += w.x * ink(float(k), ma, false, own);
    if (w.y > 0.0) col += w.y * ink(float(k), mb, true, own);
  }
  float flatness = smoothstep(0.02, 0.2, progress) * (1.0 - smoothstep(0.8, 0.98, progress));
  return vec4(mix(here.rgb, col, flatness), mix(a.a, b.a, smoothstep(0.35, 0.65, progress)));
}
