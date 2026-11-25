// Author: gre
// License: MIT
// Description: The outgoing picture turns out to be a dense shoal of silvery fish, every fish carrying its patch of it; startled, they dart, flash and turn round in a wave from the middle outward, and their other flank is the incoming picture, which swims still and smooths flat
// Tags: fish, organic, water, tiles, 3d
// Preview: 0.52

// @range(5, 16) Rows of fish, about
uniform float rows; // = 8.0
// @range(0, 1) Flash of the scales
uniform float shine; // = 0.7
// @range(0, 1) How far the fish dart as they turn
uniform float startle; // = 0.6

const float PI = 3.14159265;

vec2 hash(vec2 p) {
  vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

float startAt(vec2 s) {
  return 0.3 + 0.22 * min(length(s), 1.2);
}

// what a fish shows: patch on the picture, light, and the turned side
vec4 skin(vec4 at, float tone, float flash, vec2 eye, vec2 asp) {
  vec2 u = at.xy / asp + 0.5;
  u = 1.0 - abs(1.0 - mod(u, 2.0));
  vec4 f;
  if (at.z > 0.0) f = pm(getFromColor(u));
  else f = pm(getToColor(u));
  f.rgb = f.rgb * tone + flash * f.a * vec3(0.9, 0.97, 1.0);
  f.rgb = mix(f.rgb, vec3(0.85, 0.87, 0.85) * f.a, eye.x);
  f.rgb = mix(f.rgb, vec3(0.04) * f.a, eye.y);
  return f;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float live = smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.78, 1.0, p));
  float n = max(rows, 2.0) * 0.5 * (1.0 + 1.0 / max(ratio, 1.0));
  vec2 c0 = (uv - 0.5) * asp;
  vec2 P = c0 * n;

  // patch and side, light, flash, eye of the fish on top and of the one it covers
  vec4 at1 = vec4(0.0), at2 = vec4(0.0);
  vec2 eye1 = vec2(0.0), eye2 = vec2(0.0);
  vec2 lit1 = vec2(0.0), lit2 = vec2(0.0);
  float key1 = -100.0, key2 = -100.0;
  float shadow = 0.0;
  float row0 = floor(P.y / 0.64);
  for (int j = -3; j <= 3; j++) {
    float r = row0 - float(j);
    float shift = 0.95 * mod(r, 2.0);
    float col0 = floor((P.x - shift) / 1.9);
    for (int i = -2; i <= 2; i++) {
      vec2 id = vec2(col0 + float(i), r);
      vec2 h = hash(id + 57.0);
      vec2 home = vec2((id.x + 0.5) * 1.9 + shift, (r + 0.5) * 0.64) + (h - 0.5) * vec2(0.5, 0.2);
      // neighbours turn at different moments, so that some always fill the gaps
      float start = startAt(home / n - vec2(0.06, -0.06)) + 0.16 * (h.x - 0.5);
      float a = smoothstep(start, start + 0.15, p);
      float ca = cos(PI * a);
      float face = ca < 0.0 ? -1.0 : 1.0;
      float dp = (p - start - 0.06) / 0.11;
      float dart = startle * exp(-dp * dp);
      vec2 off = live * vec2(-ca * (0.12 + 0.55 * dart), 0.1 * sin(p * 16.0 + h.y * 6.28) + (h.y - 0.5) * 0.7 * dart);
      vec2 q = P - home - off;
      q.x /= max(abs(ca), 0.3);
      if (abs(q.x) > 2.1 || abs(q.y) > 0.95) continue;
      float x = q.x * face;
      float y0 = q.y - live * 0.1 * sin(x * 2.2 - p * 45.0 - h.x * 6.28) * smoothstep(-1.2, 1.2, x);
      float body = 0.52 * pow(max(1.0 - x * x / 1.69, 0.0), 0.75) * (1.0 - 0.2 * x);
      float tail = min((x - 0.8) * 0.62 - abs(y0), 1.6 + 0.45 * abs(y0) - x);
      float edge = max(body - abs(y0), x > 0.8 ? tail : -1.0);
      float fx = (x - 0.02) / 0.6;
      float fin = y0 > 0.0 ? body + 0.11 * (1.0 - fx * fx) - y0 : -1.0;
      edge = max(edge, fin);
      float m = smoothstep(0.0, 0.05, edge);
      if (m <= 0.0) {
        shadow = max(shadow, 0.35 * (1.0 - smoothstep(0.0, 0.22, -edge)) * (1.0 - smoothstep(0.7, 1.25, abs(x))));
        continue;
      }
      float y = y0 / max(body, 0.12);
      float tone = 1.0 + live * (0.24 * y - 0.42 * (1.0 - smoothstep(0.0, 0.1, edge)) + 0.16 * (h.x - 0.5));
      vec2 sc = vec2(x * 6.0, y0 * 7.0);
      sc.x += 0.5 * mod(floor(sc.y), 2.0);
      float ring = abs(length(fract(sc) - vec2(0.8, 0.5)) - 0.5);
      tone += live * 0.1 * (0.5 - smoothstep(0.1, 0.35, ring)) * step(abs(y), 0.9) * step(abs(x), 0.8);
      float gx = x + 0.62 - 0.25 * y * y;
      tone *= 1.0 - 0.35 * live * (1.0 - smoothstep(0.0, 0.06, abs(gx))) * step(abs(y), 0.75);
      float by = (y - 0.15 - 0.5 * ca) / 0.28;
      float flash = shine * live * (0.12 + 0.8 * dart) * exp(-by * by) * step(x, 0.85) * 0.55;
      float ed = length(vec2(x + 0.93, y0 - 0.07));
      vec2 eye = live * vec2(0.75 * (1.0 - smoothstep(0.07, 0.1, ed)), 1.0 - smoothstep(0.045, 0.07, ed));
      vec4 at = vec4((home + q) / n, face, m);
      // lower rows swim in front, and heads in front of tails
      float key = 10.0 * float(j) - x;
      if (key > key1) {
        at2 = at1;
        lit2 = vec2(lit1.x * (1.0 - 0.35 * live), lit1.y);
        eye2 = eye1;
        key2 = key1;
        at1 = at;
        lit1 = vec2(tone, flash);
        eye1 = eye;
        key1 = key;
        shadow = 0.0;
      } else if (key > key2) {
        at2 = at;
        lit2 = vec2(tone, flash);
        eye2 = eye;
        key2 = key;
      }
    }
  }
  float turned = smoothstep(-0.1, 0.18, p - startAt(c0));
  vec4 c = mix(pm(getFromColor(uv)), pm(getToColor(uv)), turned);
  float g = dot(c.rgb, vec3(0.3, 0.6, 0.1));
  // the rest of the shoal, deeper in the water
  c.rgb = mix(c.rgb, (0.6 * c.rgb + 0.5 * g * vec3(0.35, 0.7, 0.8)) * 0.72 + vec3(0.0, 0.04, 0.07) * c.a, live);
  if (at2.w > 0.0) c = mix(c, skin(at2, lit2.x, lit2.y, eye2, asp), at2.w);
  if (at1.w > 0.0) c = mix(c, skin(at1, lit1.x * (1.0 - shadow * live), lit1.y, eye1, asp), at1.w);
  return c.a > 0.0 ? vec4(min(c.rgb / c.a, 1.0), c.a) : vec4(0.0);
}
