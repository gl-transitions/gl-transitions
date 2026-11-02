// Author: gre
// License: MIT
// Description: Blocks of a solid color pop in at random over the outgoing image until they cover the frame, then pop out in another random order to show the incoming image
// Tags: blocks, grid, squares, color, cover

// @range(1, 40, 1) Number of blocks along the longer side of the frame (the blocks stay about square)
uniform int blocks; // = 16
// @color Color of the blocks
uniform vec4 color; // = vec4(0.95, 0.32, 0.26, 1.0)
// @range(0, 1) How much a block overshoots its cell as it pops in
uniform float pop; // = 0.5
// @range(0, 0.5) Softness of the blocks' edges, in blocks
uniform float smoothness; // = 0.03

const float duration = 0.14; // of one block's pop, in progress
const float cut = 0.45; // the frame is fully covered from cut - hold to cut + hold
const float hold = 0.02;

float hash (vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// eases from 0 to 1, a little past 1 (more with a larger c) and back
float backOut (float t, float c) {
  float u = t - 1.0;
  return 1.0 + (c + 1.0) * u * u * u + c * u * u;
}

// when a cell's block starts to pop in (.x) and to pop out (.y)
vec2 timing (vec2 cell) {
  return vec2(
    (cut - hold - duration) * hash(cell + 0.5),
    cut + hold + (1.0 - cut - hold - duration) * hash(cell + 71.7));
}

// scale of the block of a cell: 0 when it is not there, 1 when it fills its cell
float blockScale (vec2 cell, float c) {
  vec2 t = timing(cell);
  float a = clamp((progress - t.x) / duration, 0.0, 1.0);
  float b = clamp((progress - t.y) / duration, 0.0, 1.0);
  // it grows from nothing with an overshoot, and shrinks back to nothing
  return b > 0.0 ? (1.0 - b) * (1.0 - b) : backOut(a, c);
}

// how much of the point q (in cells) the block of a cell covers
float coverage (vec2 q, vec2 cell, float s, float sm) {
  // at scale 1, its solid part fills the whole cell, so that a covered frame shows no seams
  float h = s * (0.5 + sm);
  vec2 d = abs(q - cell - 0.5);
  return s > 0.0 ? 1.0 - smoothstep(h - sm, h, max(d.x, d.y)) : 0.0;
}

vec4 transition (vec2 uv) {
  float nLong = max(float(blocks), 1.0);
  vec2 n = ratio >= 1.0
    ? vec2(nLong, max(1.0, floor(nLong / ratio + 0.5)))
    : vec2(max(1.0, floor(nLong * ratio + 0.5)), nLong);
  vec2 q = uv * n;
  vec2 cell = floor(q);
  float sm = max(smoothness, 0.001);
  float c = 2.0 * clamp(pop, 0.0, 1.0);
  float s = blockScale(cell, c);
  if (s >= 1.0) return color;
  float cover = coverage(q, cell, s, sm);
  // a neighbour's block can overshoot onto this cell, near its border only
  float u = -2.0 * c / (3.0 * (c + 1.0));
  float reach = backOut(1.0 + u, c) * (0.5 + sm);
  vec2 o = abs(q - cell - 0.5);
  if (max(o.x, o.y) > 1.0 - reach) {
    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        vec2 nb = cell + vec2(float(i), float(j));
        vec2 inside = step(vec2(0.0), nb) * step(nb, n - 1.0);
        if (inside.x * inside.y > 0.0 && (i != 0 || j != 0)) {
          cover = max(cover, coverage(q, nb, blockScale(nb, c), sm));
        }
      }
    }
  }
  // each cell switches to the incoming image while its own block covers it
  vec2 t = timing(cell);
  vec4 under = progress < 0.5 * (t.x + duration + t.y) ? getFromColor(uv) : getToColor(uv);
  return mix(under, color, cover);
}
