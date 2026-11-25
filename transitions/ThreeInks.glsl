// Author: gre
// License: MIT
// Description: The outgoing image is reduced to three flat inks that overprint, light and dark, warm and cool, green and purple; one after another their shapes snap into a slanted plane, a disc and a band, which glide and turn through each other while they take the incoming image's colors, then break one after another into its shapes
// Tags: overprint, ink, flat, poster, palette, geometric, abstract

// @range(0, 2) How vivid the inks are
uniform float vivid; // = 1.0
// @range(0.5, 1.5) Size of the disc and of the band
uniform float size; // = 1.0

const int N = 14;
// between these two moments the inks are free of both images, so the palettes of both are read instead of their shapes
const float FREED = 0.36;
const float CAUGHT = 0.64;

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 spot(int i) {
  return fract(vec2(0.754878, 0.569840) * float(i) + 0.4);
}

// light and dark, warm and cool, green and purple
vec3 axes(vec3 c) {
  return vec3(dot(c, vec3(0.299, 0.587, 0.114)), 0.5 * (c.r - c.b), 0.5 * c.g - 0.25 * (c.r + c.b));
}

// the two chroma axes leave the luma alone
vec3 colorOf(vec3 k) {
  vec3 c = vec3(k.y, 0.0, -k.y) + k.z * vec3(-0.6, 0.6, -0.6);
  return c + k.x - dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  bool late = progress > 0.5;

  vec3 ma = vec3(0.0);
  vec3 mb = vec3(0.0);
  vec3 va = vec3(0.0);
  vec3 vb = vec3(0.0);
  vec2 sum = vec2(1e-4);
  for (int i = 0; i < N; i++) {
    vec4 ca = progress < CAUGHT ? getFromColor(spot(i)) : vec4(0.0);
    vec4 cb = progress > FREED ? getToColor(spot(i)) : vec4(0.0);
    vec3 ka = axes(ca.rgb);
    vec3 kb = axes(cb.rgb);
    sum += vec2(ca.a, cb.a);
    ma += ka * ca.a;
    mb += kb * cb.a;
    va += ka * ka * ca.a;
    vb += kb * kb * cb.a;
  }
  ma /= sum.x;
  mb /= sum.y;
  va = sqrt(max(va / sum.x - ma * ma, 0.0)) + 0.03;
  vb = sqrt(max(vb / sum.y - mb * mb, 0.0)) + 0.03;

  vec4 here = late ? b : a;
  // the inks come free, and later set, one after another
  vec3 lag = vec3(0.0, 0.06, 0.12);
  vec3 bend = smoothstep(0.0, 1.0, (late ? vec3(0.96) - lag.zyx - progress : vec3(progress) - 0.04 - lag) / 0.2);
  vec3 y = vec3(0.0);
  if (min(bend.x, min(bend.y, bend.z)) < 1.0) {
    // fine detail melts into a broad field before the shapes move, so their edges do not tear
    vec3 melt = smoothstep(0.0, 0.55, bend);
    vec4 acc = vec4(axes(here.rgb), 1.0) * here.a;
    vec4 broad = vec4(late ? mb : ma, 1.0) * 1e-3;
    if (min(melt.x, min(melt.y, melt.z)) < 1.0) {
      float soft = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
      for (int i = 0; i < N; i++) {
        float r = 0.055 * soft * sqrt((float(i) + 0.5) / float(N));
        float g = 2.39996 * float(i);
        vec2 q = fold(uv + r * vec2(cos(g), sin(g)) / vec2(ratio, 1.0));
        vec4 c = late ? getToColor(q) : getFromColor(q);
        acc += vec4(axes(c.rgb), 1.0) * c.a;
      }
    }
    if (max(melt.x, max(melt.y, melt.z)) > 0.0) {
      for (int i = 0; i < N; i++) {
        vec2 q = (uv - spot(i)) * vec2(ratio, 1.0);
        vec4 c = late ? getToColor(spot(i)) : getFromColor(spot(i));
        broad += vec4(axes(c.rgb), 1.0) * c.a * exp(-26.0 * dot(q, q));
      }
    }
    y = mix(acc.rgb / max(acc.a, 1e-4), broad.rgb / broad.a, melt);
    y = (y - (late ? mb : ma)) / (late ? vb : va) * 0.22;
  }

  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float t = progress * 3.14159;
  vec2 center = vec2(0.22 * ratio * cos(t), 0.1 * sin(t));
  float disc = 0.36 * size * min(1.0, 0.4 + 0.5 * ratio) - length(p - center);
  vec2 d = vec2(cos(t * 0.5 + 0.6), sin(t * 0.5 + 0.6));
  float band = 0.17 * size - abs(dot(p, d) - 0.1 * cos(t));
  vec2 e = vec2(cos(-t * 0.7 + 2.2), sin(-t * 0.7 + 2.2));
  float plane = dot(p, e) - 0.08 * sin(2.0 * t);
  vec3 aa = mix(vec3(0.02), vec3(0.002), bend);
  vec3 ink = smoothstep(-aa, aa, mix(y, vec3(plane, disc, band), bend));

  float turn = smoothstep(0.37, 0.63, progress);
  // a transparent image has no palette to turn to
  turn = turn * sum.y / (turn * sum.y + (1.0 - turn) * sum.x);
  ink = (2.0 * ink - 1.0) * vec3(1.15, 1.25, 1.4);
  vec3 k = mix(ma + va * ink, mb + vb * ink, turn);
  vec3 col = colorOf(k);
  // an overprint takes the hue of the closest place of the images, so that none strays from them
  vec4 pa = vec4(0.0);
  vec4 pb = vec4(0.0);
  for (int i = 0; i < N; i++) {
    if (turn < 1.0) {
      vec4 q = getFromColor(spot(i));
      vec3 d = q.rgb - col;
      pa += vec4(q.rgb, 1.0) * (q.a * exp(-30.0 * dot(d, d)) + 1e-5);
    }
    if (turn > 0.0) {
      vec4 q = getToColor(spot(i));
      vec3 d = q.rgb - col;
      pb += vec4(q.rgb, 1.0) * (q.a * exp(-30.0 * dot(d, d)) + 1e-5);
    }
  }
  vec3 near = axes(mix(pa.rgb / max(pa.a, 1e-5), pb.rgb / max(pb.a, 1e-5), turn));
  k.yz = mix(k.yz, near.yz, 0.6) * (1.0 + 0.6 * vivid);
  col = clamp(colorOf(k), 0.0, 1.0);

  float flatness = smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
  return vec4(mix(here.rgb, col, flatness), mix(a.a, b.a, smoothstep(0.34, 0.66, progress)));
}
