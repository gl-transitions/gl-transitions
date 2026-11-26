// Author: gre
// License: MIT
// Description: Pen lines are drawn one after another between the dots of a grid over the picture; each time a square gets its fourth side it pops open on its part of the incoming picture, often two at once when one line closes both, until the grid is complete and the lines fade
// Tags: grid, pen, game, boxes, drawing, squares

// @range(3, 12) Number of boxes along the frame's short side
uniform float boxes; // = 5.0
// @range(0.003, 0.03) Thickness of the pen lines, in fractions of the frame's short side
uniform float thickness; // = 0.012
// @color Color of the pen lines
uniform vec4 pen; // = vec4(0.08, 0.08, 0.1, 1.0)

const float DRAW = 0.06;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Most sides come early so the boxes, which wait for their last side, close at an even pace.
float sideStart(vec2 id, float vertical) {
  float h = hash(id + vertical * vec2(17.0, 29.0));
  return 0.04 + 0.74 * h * h * h;
}

// x runs along the side in [0,1], y across it
float side(vec2 l, float t0, float w, float flip, float len) {
  float k = clamp((progress - t0) / DRAW, 0.0, 1.0);
  float x = mix(l.x, 1.0 - l.x, flip) * len;
  float d = length(vec2(max(x - k * len, 0.0), l.y));
  return (1.0 - smoothstep(w * 0.5 - 0.0012, w * 0.5 + 0.0012, d)) * step(0.0001, k);
}

vec4 transition(vec2 uv) {
  float n = floor(boxes);
  vec2 frame = ratio < 1.0 ? vec2(1.0, 1.0 / ratio) : vec2(ratio, 1.0);
  vec2 grid = max(vec2(1.0), floor(n * frame + 0.5));
  vec2 cs = frame / grid;
  vec2 p = uv * grid;
  vec2 id = floor(p);
  vec2 q = p - id;
  float env = smoothstep(0.0, 0.03, progress) * (1.0 - smoothstep(0.93, 1.0, progress));
  float w = thickness * env;

  float tB = sideStart(id, 0.0);
  float tT = sideStart(id + vec2(0.0, 1.0), 0.0);
  float tL = sideStart(id, 1.0);
  float tR = sideStart(id + vec2(1.0, 0.0), 1.0);
  float closed = max(max(tB, tT), max(tL, tR)) + DRAW;

  float k = smoothstep(closed, closed + 0.05, progress);
  vec2 c = abs(q - 0.5) * cs;
  float r = k * 0.5 * max(cs.x, cs.y) * 1.5;
  float inBox = 1.0 - smoothstep(r - 0.004, r, max(c.x, c.y) + 0.3 * min(c.x, c.y) * (1.0 - k));
  vec4 col = mix(getFromColor(uv), getToColor(uv), inBox);
  col.rgb *= 1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.08, progress - closed - 0.05)) * k;

  float ink = side(vec2(q.x, q.y * cs.y), tB, w, step(0.5, hash(id + vec2(41.0, 73.0))), cs.x);
  ink = max(ink, side(vec2(q.x, (1.0 - q.y) * cs.y), tT, w, step(0.5, hash(id + vec2(41.0, 74.0))), cs.x));
  ink = max(ink, side(vec2(q.y, q.x * cs.x), tL, w, step(0.5, hash(id + vec2(59.0, 23.0))), cs.y));
  ink = max(ink, side(vec2(q.y, (1.0 - q.x) * cs.x), tR, w, step(0.5, hash(id + vec2(60.0, 23.0))), cs.y));
  vec2 dc = min(q, 1.0 - q) * cs;
  ink = max(ink, 1.0 - smoothstep(w * 1.1 - 0.0012, w * 1.1 + 0.0012, length(dc)));
  return mix(col, pen, ink * env * pen.a);
}
