// Author: gre
// License: MIT
// Description: The outgoing image slumps from the sky down into layered hills of its own flat colors; as the view travels over them, the hills turn one after another, from the farthest to the nearest, into those of the incoming image, which then grows out of the ground up to the sky
// Tags: hills, landscape, layers, flat, palette, parallax, abstract

// @range(0, 0.1) Height of the waves running along the hills, in frame heights
uniform float waves; // = 0.04
// @range(0, 2) How fast the view travels over the hills
uniform float travel; // = 1.0
// @range(0, 2.5) How vivid the flat colors are
uniform float vivid; // = 1.4

const int N = 14;
// between these two moments the shapes are free of both images, so the palettes of both are read instead of their shapes
const float FREED = 0.36;
const float CAUGHT = 0.64;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 spot(int i) {
  return fract(vec2(0.754878, 0.569840) * float(i) + 0.4);
}

// how much the color c stands for a tone: the ones that stand out win, since the average of several hues is mud
float weight(vec4 c, vec2 stats, vec3 tint, float z) {
  float l = luma(c.rgb);
  float d = (l - stats.x) / stats.y - z;
  float s = 0.4 * length(c.rgb - l) + length(c.rgb - l - tint);
  float w = exp(-4.0 * d * d) * (0.1 + s);
  w *= w * w;
  return c.a * w * w + 1e-7;
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  bool late = progress > 0.5;

  vec2 ma = vec2(0.0);
  vec2 mb = vec2(0.0);
  vec3 ta = vec3(0.0);
  vec3 tb = vec3(0.0);
  vec2 sum = vec2(1e-4);
  for (int i = 0; i < N; i++) {
    vec4 ca = progress < CAUGHT ? getFromColor(spot(i)) : vec4(0.0);
    vec4 cb = progress > FREED ? getToColor(spot(i)) : vec4(0.0);
    vec2 l = vec2(luma(ca.rgb), luma(cb.rgb));
    sum += vec2(ca.a, cb.a);
    ma += vec2(l.x, l.x * l.x) * ca.a;
    mb += vec2(l.y, l.y * l.y) * cb.a;
    ta += (ca.rgb - l.x) * ca.a;
    tb += (cb.rgb - l.y) * cb.a;
  }
  ma /= sum.x;
  mb /= sum.y;
  ta /= sum.x;
  tb /= sum.y;
  ma.y = sqrt(max(ma.y - ma.x * ma.x, 0.0)) + 0.03;
  mb.y = sqrt(max(mb.y - mb.x * mb.x, 0.0)) + 0.03;

  vec4 here = late ? b : a;
  float when = late ? 0.84 + 0.12 * uv.y - progress : progress - 0.04 - 0.12 * (1.0 - uv.y);
  float bend = smoothstep(0.0, 1.0, when / 0.2);
  float y = 0.0;
  if (bend < 1.0) {
    // fine detail melts into a broad field before the shapes move, so their edges do not tear
    float melt = smoothstep(0.0, 0.55, bend);
    vec2 acc = vec2(luma(here.rgb) * here.a, here.a);
    vec2 broad = vec2(late ? mb.x : ma.x, 1.0) * 1e-3;
    if (melt < 1.0) {
      float soft = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
      for (int i = 0; i < N; i++) {
        float r = 0.055 * soft * sqrt((float(i) + 0.5) / float(N));
        float g = 2.39996 * float(i);
        vec2 q = fold(uv + r * vec2(cos(g), sin(g)) / vec2(ratio, 1.0));
        vec4 c = late ? getToColor(q) : getFromColor(q);
        acc += vec2(luma(c.rgb) * c.a, c.a);
      }
    }
    if (melt > 0.0) {
      for (int i = 0; i < N; i++) {
        vec2 q = (uv - spot(i)) * vec2(ratio, 1.0);
        vec4 c = late ? getToColor(spot(i)) : getFromColor(spot(i));
        broad += vec2(luma(c.rgb), 1.0) * c.a * exp(-26.0 * dot(q, q));
      }
    }
    y = mix(acc.x / max(acc.y, 1e-4), broad.x / broad.y, melt);
    y = (y - (late ? mb.x : ma.x)) / (late ? mb.y : ma.y);
  }
  float aa = mix(0.03, 0.002, bend);
  // the four hills, from the farthest to the nearest; the sky is behind them
  vec4 nears = vec4(0.25, 0.5, 0.75, 1.0);
  vec4 ks = vec4(3.0, 2.0, 1.0, 0.0);
  vec4 zc = (ks - 2.0) * 0.62 + 0.31;
  vec4 turns = smoothstep(0.0, 1.0, (progress - (0.36 - 0.02 * (ks - 4.0))) / 0.18);
  vec4 top = vec4(0.0);
  if (bend > 0.0) {
    vec4 grownA = vec4(0.0);
    vec4 grownB = vec4(0.0);
    vec4 totalA = vec4(1e-4);
    vec4 totalB = vec4(1e-4);
    vec4 xa = uv.x + 0.5 * travel * nears * progress;
    vec4 xb = uv.x + 0.5 * travel * nears * (progress - 1.0);
    for (int i = 0; i < N; i++) {
      if (progress < CAUGHT) {
        vec4 c = getFromColor(spot(i));
        vec4 dx = fract(spot(i).x - xa + 0.5) - 0.5;
        vec4 w = exp(-16.0 * dx * dx) * c.a;
        totalA += w;
        grownA += w * smoothstep(-0.5, 0.5, zc - (luma(c.rgb) - ma.x) / ma.y);
      }
      if (progress > FREED) {
        vec4 c = getToColor(spot(i));
        vec4 dx = fract(spot(i).x - xb + 0.5) - 0.5;
        vec4 w = exp(-16.0 * dx * dx) * c.a;
        totalB += w;
        grownB += w * smoothstep(-0.5, 0.5, zc - (luma(c.rgb) - mb.x) / mb.y);
      }
    }
    top = 0.04 + 0.78 * mix(grownA / totalA, grownB / totalB, turns) + 0.02 * ks;
    top += waves * sin(uv.x * ratio * (3.0 + 1.6 * nears) + 9.6 * nears + travel * progress * (4.0 + 9.0 * nears));
  }
  vec4 covers = smoothstep(-aa, aa, mix(0.22 * (zc - y), top - uv.y, bend));
  vec3 col = vec3(0.0);
  float left = 1.0;
  for (int j = 4; j >= 0; j--) {
    float cover = j == 4 ? covers.w : j == 3 ? covers.z : j == 2 ? covers.y : j == 1 ? covers.x : 1.0;
    if (cover <= 0.0) continue;
    float k = 4.0 - float(j);
    // the tone, in deviations from the mean
    float z = (k - 2.0) * 0.62;
    float turn = smoothstep(0.0, 1.0, (progress - (0.36 - 0.02 * (k - 4.0))) / 0.18);
    vec4 pa = vec4(0.0);
    vec4 pb = vec4(0.0);
    for (int i = 0; i < N; i++) {
      if (turn < 1.0) {
        vec4 q = getFromColor(spot(i));
        pa += vec4(q.rgb, 1.0) * weight(q, ma, ta, z);
      }
      if (turn > 0.0) {
        vec4 q = getToColor(spot(i));
        pb += vec4(q.rgb, 1.0) * weight(q, mb, tb, z);
      }
    }
    vec3 c = mix(pa.rgb / max(pa.a, 1e-7), pb.rgb / max(pb.a, 1e-7), turn);
    float goal = mix(ma.x + 1.2 * z * ma.y, mb.x + 1.2 * z * mb.y, turn);
    c = clamp(goal + (c - luma(c)) * vivid, 0.0, 1.0);
    col += left * cover * c;
    left *= 1.0 - cover;
    if (left <= 0.0) break;
  }

  float flatness = smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
  return vec4(mix(here.rgb, col, flatness), mix(a.a, b.a, smoothstep(0.34, 0.66, progress)));
}
