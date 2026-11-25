// Author: gre
// License: MIT
// Description: The outgoing image breaks into a board of dots in four of its inks; neighbors of the same ink reach out and join into pills, bends and big soft-cornered shapes; dot by dot they let go, shrink and come back in the incoming image's inks, join again and swell into the incoming image
// Tags: dots, grid, links, flat, poster, palette, abstract
// Preview: 0.4

// @range(0.06, 0.25) Distance between the dots, as a part of the frame's shorter side
uniform float pitch; // = 0.125
// @range(0, 2.5) How vivid the inks are
uniform float vivid; // = 1.5

const int N = 8;
const int TAPS = 8;
// between these two moments only the dots show, so the palettes of both images are read instead of their shapes
const float FREED = 0.22;
const float CAUGHT = 0.78;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 spot(int i) {
  return fract(vec2(0.754878, 0.569840) * float(i) + 0.4);
}

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float during(float a, float b) {
  return smoothstep(a, b, progress);
}

vec4 pixel(vec2 p, bool late) {
  return late ? getToColor(p) : getFromColor(p);
}

vec3 paint(vec4 sum, float level) {
  vec3 c = sum.rgb / sum.a;
  float l = luma(c);
  return clamp(l + (c - l) * vivid + 0.06 * (level - 1.5), 0.0, 1.0);
}

float halfPill(vec2 p, vec2 d, float len) {
  return length(p - d * clamp(dot(p, d) / dot(d, d), 0.0, 0.5 * len));
}

// a link growing from both of its dots
float link(vec2 p, vec2 d, float len, float r) {
  float m = min(halfPill(p, d, len), halfPill(p - d, -d, len));
  return len > 0.0 ? r - m : -9.0;
}

// rounds off the bend between two links
vec4 bent(vec4 a, vec4 b) {
  vec4 h = max(0.3 - abs(a - b), 0.0);
  return max(a, b) + h * h / 1.2;
}

float linked(vec3 same, vec3 d) {
  d = mix(vec3(-9.0), d, same);
  return max(d.x, max(d.y, d.z));
}

// keeps the two best scores: x and y hold the inks, z and w their scores
vec4 rank(vec4 best, float k, float score) {
  return score > best.z ? vec4(k, best.x, score, best.z) : score > best.w ? vec4(best.x, k, best.z, score) : best;
}

float toneOf(float k, float z, bool late) {
  return (k > 3.5) == late ? 0.5 - abs(z - mod(k, 4.0)) : -9.0;
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  bool late = progress > 0.5;
  vec2 frame = vec2(ratio, 1.0) / min(ratio, 1.0);

  // the color to fall back on where the spots of an image are all transparent
  vec3 own = (a.rgb * a.a + b.rgb * b.a) / max(a.a + b.a, 1e-4);
  vec2 sum = vec2(1e-4);
  vec2 ma = 1e-4 * vec2(luma(own), luma(own) * luma(own));
  vec2 mb = ma;
  vec3 ga = 1e-4 * own;
  vec3 gb = ga;
  for (int i = 0; i < N; i++) {
    vec4 ca = progress < CAUGHT ? getFromColor(spot(i)) : vec4(0.0);
    vec4 cb = progress > FREED ? getToColor(spot(i)) : vec4(0.0);
    vec2 l = vec2(luma(ca.rgb), luma(cb.rgb));
    sum += vec2(ca.a, cb.a);
    ma += vec2(l.x, l.x * l.x) * ca.a;
    mb += vec2(l.y, l.y * l.y) * cb.a;
    ga += ca.rgb * ca.a;
    gb += cb.rgb * cb.a;
  }
  vec3 ground = mix(mix(ga, gb, during(0.36, 0.64)) / mix(sum.x, sum.y, during(0.36, 0.64)), vec3(1.0), 0.75);
  ma /= sum.x;
  mb /= sum.y;
  ma.y = sqrt(max(ma.y - ma.x * ma.x, 0.0)) + 0.03;
  mb.y = sqrt(max(mb.y - mb.x * mb.x, 0.0)) + 0.03;

  vec2 g = (uv - 0.5) * frame / pitch + 0.5;
  vec2 cell = floor(g), f = g - cell;
  vec4 ink, size;
  for (int i = 0; i < 4; i++) {
    vec2 n = vec2(mod(float(i), 2.0), floor(0.5 * float(i)));
    vec2 id = cell + n;
    float t = (progress - 0.38 - 0.24 * hash(id + 50.0)) / 0.08;
    bool turned = t > 0.0;
    vec2 q = fold((id - 0.5) * pitch / frame + 0.5);
    float l = luma(pixel(q, turned).rgb);
    float y = turned ? (l - mb.x) / mb.y : (l - ma.x) / ma.y;
    float k = floor(clamp(y / 0.8 + 2.0, 0.0, 3.99)) + (turned ? 4.0 : 0.0);
    float s = smoothstep(0.0, 1.0, abs(t));
    if (i == 0) { ink.x = k; size.x = s; }
    else if (i == 1) { ink.y = k; size.y = s; }
    else if (i == 2) { ink.z = k; size.z = s; }
    else { ink.w = k; size.w = s; }
  }

  vec4 same = step(abs(ink.xzxy - ink.ywzw), vec4(0.5));
  vec2 diag = step(abs(ink.xy - ink.wz), vec2(0.5));
  float grow = 1.0 - during(0.06, 0.32) + during(0.68, 0.92);
  float radius = mix(0.35, 0.78, grow);
  // links along the two rows, along the two columns, then across a square of one ink
  vec4 w = min(size.xzxy, size.ywzw);
  vec4 len = same * smoothstep(0.2, 0.8, w) * vec2(during(0.2, 0.34), during(0.26, 0.42)).xxyy;
  vec2 wd = min(size.xy, size.wz);
  vec2 lend = same.x * same.y * same.z * during(0.3, 0.5) * smoothstep(0.2, 0.8, wd);
  vec2 X = vec2(1.0, 0.0), Y = X.yx;
  // shrunk away, a dot leaves no speck
  vec4 dots = (radius + 0.03) * size - 0.03 - vec4(length(f), length(f - X), length(f - Y), length(f - 1.0));
  vec4 l = vec4(link(f, X, len.x, radius * w.x), link(f - Y, X, len.y, radius * w.y), link(f, Y, len.z, radius * w.z), link(f - X, Y, len.w, radius * w.w));
  vec2 ld = vec2(link(f, X + Y, lend.x, radius * wd.x), link(f - X, Y - X, lend.y, radius * wd.y));
  vec4 sd = max(max(dots, ld.xyyx), bent(l.xxyy, l.zwzw));
  sd = max(sd, vec4(
    linked(vec3(same.xz, diag.x), sd.yzw),
    linked(vec3(same.x, diag.y, same.w), sd.xzw),
    linked(vec3(same.z, diag.y, same.y), sd.xyw),
    linked(vec3(diag.x, same.wy), sd.xyz)));
  sd = max(sd, -1.5);

  float bend = late ? 1.0 - during(0.78, 0.96) : during(0.04, 0.2);
  vec4 here = late ? b : a;
  vec2 acc = vec2(luma(here.rgb), 1.0) * here.a + vec2(0.0, 1e-5);
  if (progress < FREED || progress > CAUGHT) {
    float soft = 0.035 * (late ? 1.0 - during(0.8, 1.0) : during(0.0, 0.2));
    for (int i = 0; i < TAPS; i++) {
      float n = 2.39996 * float(i);
      vec4 c = pixel(fold(uv + soft * sqrt((float(i) + 0.5) / float(TAPS)) * vec2(cos(n), sin(n)) / frame), late);
      acc += vec2(luma(c.rgb), 1.0) * c.a;
    }
  }
  float z = (acc.x / acc.y - (late ? mb.x : ma.x)) / (late ? mb.y : ma.y);
  z = clamp(z / 0.8 + 1.5, -0.5, 3.5);

  // the inks of the dots, then of the picture itself, for the first and last beats
  vec4 dup = vec4(0.0, same.x, max(same.z, diag.y), max(diag.x, max(same.w, same.y)));
  vec4 tone = vec4(toneOf(ink.x, z, late), toneOf(ink.y, z, late), toneOf(ink.z, z, late), toneOf(ink.w, z, late));
  vec4 score = mix(0.3 * tone, sd, bend) - 99.0 * dup;
  vec4 best = vec4(-1.0, -1.0, mix(-0.2, 0.0, bend) - 0.2 * grow, -99.0);
  best = rank(best, ink.x, score.x);
  best = rank(best, ink.y, score.y);
  best = rank(best, ink.z, score.z);
  best = rank(best, ink.w, score.w);
  float k = clamp(floor(z), 0.0, 2.0) + (late ? 4.0 : 0.0);
  for (int i = 0; i < 2; i++) {
    float known = dot(step(abs(ink - k), vec4(0.5)), vec4(1.0));
    best = rank(best, k, mix(0.3 * toneOf(k, z, late), -1.5, bend) - 99.0 * known);
    k += 1.0;
  }

  vec2 level = mod(best.xy, 4.0);
  vec2 second = step(3.5, best.xy);
  // the ground needs no palette, and a far second neither
  second.x = best.x < 0.0 ? second.y : second.x;
  second.y = best.y < 0.0 || best.z - best.w > 0.02 + 0.0025 / pitch ? second.x : second.y;
  vec4 s0 = 1e-6 * vec4(own, 1.0), s1 = s0;
  for (int i = 0; i < N; i++) {
    if (second.x + second.y < 1.5) {
      vec4 c = getFromColor(spot(i));
      vec2 d = (luma(c.rgb) - ma.x) / ma.y / 0.8 + 1.5 - level;
      vec2 w = (1.0 - second) * c.a * (exp(-4.0 * d * d) + 1e-3);
      s0 += vec4(c.rgb, 1.0) * w.x;
      s1 += vec4(c.rgb, 1.0) * w.y;
    }
    if (second.x + second.y > 0.5) {
      vec4 c = getToColor(spot(i));
      vec2 d = (luma(c.rgb) - mb.x) / mb.y / 0.8 + 1.5 - level;
      vec2 w = second * c.a * (exp(-4.0 * d * d) + 1e-3);
      s0 += vec4(c.rgb, 1.0) * w.x;
      s1 += vec4(c.rgb, 1.0) * w.y;
    }
  }
  vec3 c0 = best.x < 0.0 ? ground : paint(s0, level.x);
  vec3 c1 = best.y < 0.0 ? ground : paint(s1, level.y);
  float aa = mix(0.015, 0.0025 / pitch, bend);
  vec3 col = mix(c1, c0, smoothstep(-aa, aa, best.z - best.w));

  float light = luma(here.rgb);
  float on = smoothstep(0.0, 0.12, progress - 0.06 * light) * smoothstep(0.0, 0.14, 1.0 - 0.06 * light - progress);
  return vec4(mix(here.rgb, col, on), mix(a.a, b.a, during(0.35, 0.65)));
}
