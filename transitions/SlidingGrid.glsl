// Author: gre
// License: MIT
// Description: Black lines slide in from the edges over the outgoing image and divide it into panels whose shapes sink, tone after tone, into flat colors; the lines keep shifting, the panels widening and narrowing, while the incoming image's colors pour across them, then its shapes surface out of the colors and the lines slide out
// Tags: grid, lines, panels, flat, palette, abstract, painting
// Preview: 0.25

// @range(0, 0.04) Width of the lines, as a part of the frame's shorter side
uniform float thickness; // = 0.016
// @color Color of the lines
uniform vec4 lineColor; // = vec4(0.04, 0.04, 0.04, 1.0)
// @range(0, 1) How far the lines keep shifting
uniform float shift; // = 0.7
// @range(0, 2) How vivid the flat colors are
uniform float vivid; // = 0.8

const int LEVELS = 4;
const int TAPS = 16;
const int SPOTS = 7;

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 pixel(vec2 p, bool incoming) {
  return incoming ? getToColor(p) : getFromColor(p);
}

// the flat color of a panel: what stands out wins, since the average of several hues is mud
vec4 paint(vec2 lo, vec2 hi, bool incoming) {
  vec4 acc = vec4(0.0);
  float total = 0.0;
  for (int i = 0; i < SPOTS; i++) {
    vec4 c = pixel(mix(lo, hi, 0.15 + 0.7 * fract(vec2(0.754878, 0.569840) * float(i) + 0.4)), incoming);
    float w = 0.05 + max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    w *= w;
    acc += vec4(c.rgb * c.a, c.a) * w;
    total += w;
  }
  vec3 c = acc.rgb / max(acc.a, 1e-5);
  float y = dot(c, vec3(0.299, 0.587, 0.114));
  return vec4(clamp(y + (c - y) * (1.0 + vivid), 0.0, 1.0), acc.a / total);
}

vec4 transition(vec2 uv) {
  bool late = progress > 0.5;
  float u = late ? 1.0 - progress : progress;
  vec2 frame = vec2(ratio, 1.0);
  vec2 p = uv * frame;
  vec2 lo = vec2(0.0);
  vec2 hi = frame;
  // the panel at rest, where its colors are read, so that they hold still while the lines move
  vec2 restLo = lo;
  vec2 restHi = hi;
  float id = 1.0;
  float edge = 1.0;
  float width = 0.5 * thickness * min(ratio, 1.0) * smoothstep(0.0, 0.15, u);
  for (int l = 0; l < LEVELS; l++) {
    if (l == LEVELS - 1 && hash(id + 11.0) < 0.45) {
      id *= 2.0;
      continue;
    }
    float rest = 0.3 + 0.4 * hash(id + 2.0);
    float s = rest + 0.26 * shift * sin((hash(id + 60.0) > 0.5 ? 6.0 : -6.0) * (progress - 0.5) + 2.0 * hash(id + 80.0) - 1.0);
    float enter = smoothstep(0.0, 0.28, u - 0.025 * float(l));
    s = mix((hash(id + 31.0) > 0.5) != late ? 1.06 : -0.06, s, enter);
    vec2 axis = (mod(float(l), 2.0) < 0.5) == (ratio >= 1.0) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec2 at = mix(lo, hi, s);
    vec2 restAt = mix(restLo, restHi, rest);
    float v = dot(p - at, axis);
    edge = min(edge, abs(v) - width);
    float side = step(0.0, v);
    lo = mix(lo, at, axis * side);
    hi = mix(hi, at, axis * (1.0 - side));
    restLo = mix(restLo, restAt, axis * side);
    restHi = mix(restHi, restAt, axis * (1.0 - side));
    id = id * 2.0 + side;
  }

  float sunk = clamp((u - 0.08) / 0.32, 0.0, 1.0);
  vec4 here = pixel(uv, late);
  vec4 acc = vec4(here.rgb, 1.0) * here.a + vec4(0.0, 0.0, 0.0, 1e-5);
  float r = 0.03 * smoothstep(0.02, 0.3, u);
  for (int i = 0; i < TAPS; i++) {
    float a = 2.399963 * float(i);
    vec4 c = pixel(fold(uv + r * sqrt((float(i) + 0.5) / float(TAPS)) * vec2(cos(a), sin(a)) / frame), late);
    acc += vec4(c.rgb, 1.0) * c.a;
  }
  vec4 soft = vec4(acc.rgb / acc.a, here.a);
  soft.rgb = mix(here.rgb, soft.rgb, smoothstep(0.0, 0.1, u));

  float pour = smoothstep(0.0, 1.0, (progress - 0.38 - 0.1 * hash(id + 90.0)) / 0.14);
  float way = hash(id + 70.0);
  vec2 q = (p - lo) / max(hi - lo, 1e-4);
  q = way < 0.5 ? q : 1.0 - q;
  bool tall = hi.y - lo.y > hi.x - lo.x;
  float len = tall ? hi.y - lo.y : hi.x - lo.x;
  float front = ((tall ? q.y : q.x) - pour) * len;
  float flow = 1.0 - smoothstep(-0.0015, 0.0015, front + mix(0.0015, -0.0015, pour));
  restLo /= frame;
  restHi /= frame;
  vec4 flat0 = paint(restLo, restHi, false);
  vec4 flat1 = paint(restLo, restHi, true);
  vec4 col = late ? flat1 : flat0;
  // the tones of a panel sink into its color one after another, the closest first
  float sink = smoothstep(0.0, 0.12, 1.9 * sunk * sunk - length(soft.rgb - col.rgb));
  col = mix(flat0, flat1, flow);
  col.rgb = mix(soft.rgb, col.rgb, sink);
  col.a = mix(here.a, col.a, sink);
  float ink = 1.0 - smoothstep(-0.0015, 0.0015, edge);
  ink *= smoothstep(0.0, 0.002, width);
  return mix(col, vec4(lineColor.rgb, lineColor.a * col.a), ink);
}
