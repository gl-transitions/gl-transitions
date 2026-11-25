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

  vec4 ca[N];
  vec4 cb[N];
  vec2 ma = vec2(0.0);
  vec2 mb = vec2(0.0);
  vec3 ta = vec3(0.0);
  vec3 tb = vec3(0.0);
  vec2 sum = vec2(1e-4);
  for (int i = 0; i < N; i++) {
    ca[i] = progress < CAUGHT ? getFromColor(spot(i)) : vec4(0.0);
    cb[i] = progress > FREED ? getToColor(spot(i)) : vec4(0.0);
    vec2 l = vec2(luma(ca[i].rgb), luma(cb[i].rgb));
    sum += vec2(ca[i].a, cb[i].a);
    ma += vec2(l.x, l.x * l.x) * ca[i].a;
    mb += vec2(l.y, l.y * l.y) * cb[i].a;
    ta += (ca[i].rgb - l.x) * ca[i].a;
    tb += (cb[i].rgb - l.y) * cb[i].a;
  }
  ma /= sum.x;
  mb /= sum.y;
  ta /= sum.x;
  tb /= sum.y;
  ma.y = sqrt(max(ma.y - ma.x * ma.x, 0.0)) + 0.03;
  mb.y = sqrt(max(mb.y - mb.x * mb.x, 0.0)) + 0.03;

  float soft = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  vec4 here = late ? b : a;
  vec2 acc = vec2(luma(here.rgb) * here.a, here.a);
  if (progress < FREED || progress > CAUGHT) {
    for (int i = 0; i < N; i++) {
      float r = 0.055 * soft * sqrt((float(i) + 0.5) / float(N));
      float g = 2.39996 * float(i);
      vec2 q = fold(uv + r * vec2(cos(g), sin(g)) / vec2(ratio, 1.0));
      vec4 c = late ? getToColor(q) : getFromColor(q);
      acc += vec2(luma(c.rgb) * c.a, c.a);
    }
  }

  float when = late ? 0.84 + 0.12 * uv.y - progress : progress - 0.04 - 0.12 * (1.0 - uv.y);
  float bend = smoothstep(0.0, 1.0, when / 0.2);
  // fine detail melts into a broad field before the shapes move, so their edges do not tear
  vec2 broad = vec2(late ? mb.x : ma.x, 1.0) * 1e-3;
  for (int i = 0; i < N; i++) {
    vec2 q = (uv - spot(i)) * vec2(ratio, 1.0);
    vec4 c = late ? cb[i] : ca[i];
    broad += vec2(luma(c.rgb), 1.0) * c.a * exp(-26.0 * dot(q, q));
  }
  float y = mix(acc.x / max(acc.y, 1e-4), broad.x / broad.y, smoothstep(0.0, 0.55, bend));
  y = (y - (late ? mb.x : ma.x)) / (late ? mb.y : ma.y);
  float aa = mix(0.03, 0.002, bend);
  vec3 col = vec3(0.0);
  for (int j = 0; j < 5; j++) {
    // from the sky, the lightest, to the nearest hill, the darkest
    float near = 0.25 * float(j);
    float k = 4.0 - float(j);
    // the tone, in deviations from the mean
    float z = (k - 2.0) * 0.62;
    vec4 pa = vec4(0.0);
    vec4 pb = vec4(0.0);
    for (int i = 0; i < N; i++) {
      pa += vec4(ca[i].rgb, 1.0) * weight(ca[i], ma, ta, z);
      pb += vec4(cb[i].rgb, 1.0) * weight(cb[i], mb, tb, z);
    }
    float turn = smoothstep(0.0, 1.0, (progress - (0.36 - 0.02 * (k - 4.0))) / 0.18);
    vec3 c = mix(pa.rgb / pa.a, pb.rgb / pb.a, turn);
    float goal = mix(ma.x + 1.2 * z * ma.y, mb.x + 1.2 * z * mb.y, turn);
    c = clamp(goal + (c - luma(c)) * vivid, 0.0, 1.0);
    float h = 1.0;
    if (j > 0) {
      float zc = z + 0.31;
      vec2 grown = vec2(0.0);
      vec2 total = vec2(1e-4);
      vec2 x = uv.x + 0.5 * travel * near * vec2(progress, progress - 1.0);
      for (int i = 0; i < N; i++) {
        vec2 dx = fract(spot(i).x - x + 0.5) - 0.5;
        vec2 w = exp(-16.0 * dx * dx) * vec2(ca[i].a, cb[i].a);
        vec2 d = (vec2(luma(ca[i].rgb), luma(cb[i].rgb)) - vec2(ma.x, mb.x)) / vec2(ma.y, mb.y);
        total += w;
        grown += w * smoothstep(-0.5, 0.5, zc - d);
      }
      grown /= total;
      float top = 0.04 + 0.78 * mix(grown.x, grown.y, turn) + 0.02 * k;
      top += waves * sin(uv.x * ratio * (3.0 + 1.6 * near) + 9.6 * near + travel * progress * (4.0 + 9.0 * near));
      h = mix(0.22 * (zc - y), top - uv.y, bend);
    }
    col = mix(col, c, j == 0 ? 1.0 : smoothstep(-aa, aa, h));
  }

  float flatness = smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
  return vec4(mix(here.rgb, col, flatness), mix(a.a, b.a, smoothstep(0.34, 0.66, progress)));
}
