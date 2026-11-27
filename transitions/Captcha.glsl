// Author: gre
// License: MIT
// Description: Gutters split the outgoing picture into an image-challenge grid; tile after tile is clicked in an overlapping cascade, shrinking inside its square under a check badge, then washing out and growing back as its part of the incoming picture, until the gutters close
// Tags: grid, tiles, puzzle, game

// @range(2.0, 6.0) Number of tiles along the short side
uniform float tiles; // = 3.0
// @range(0.15, 0.6) Duration of one tile's click-and-reload, in progress units
uniform float span; // = 0.35
// @color Gutters between the tiles and the wash of a reloading tile
uniform vec4 gutter; // = vec4(1.0, 1.0, 1.0, 1.0)
// @color Check badge of a clicked tile
uniform vec4 badge; // = vec4(0.1, 0.45, 0.91, 1.0)

const float PI = 3.14159265;

float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

vec4 transition(vec2 uv) {
  bool portrait = ratio < 1.0;
  vec2 st = portrait ? uv.yx : uv;
  float aspect = max(ratio, 1.0 / ratio);
  float rows = max(floor(tiles + 0.5), 1.0);
  vec2 grid = vec2(floor(rows * aspect + 0.5), rows);
  vec2 cell = min(floor(st * grid), grid - 1.0);
  vec2 shape = vec2(aspect * grid.y / grid.x, 1.0);
  vec2 q = (st * grid - cell - 0.5) * shape;
  vec2 halfSize = 0.5 * shape;
  float px = grid.y / 500.0;

  float gap = 0.04 * smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.92, 1.0, progress));

  // golden-ratio ranks spread the clicks evenly over time for any grid size
  float rank = fract((cell.y * grid.x + cell.x) * 0.618034);
  float t0 = 0.02 + (0.96 - span) * rank;
  float u = clamp((progress - t0) / span, 0.0, 1.0);

  float dip = sin(PI * smoothstep(0.0, 1.0, u));
  float scale = 1.0 - 0.2 * dip - gap;
  float wash = 0.7 * smoothstep(0.25, 0.5, u) * (1.0 - smoothstep(0.5, 0.8, u));

  vec2 lq = q / scale;
  // clamped so the antialiased rim never samples the neighbouring cell
  vec2 tuv = (cell + 0.5 + clamp(lq / shape, -0.5, 0.5)) / grid;
  if (portrait) tuv = tuv.yx;
  vec4 img = mix(getFromColor(tuv), getToColor(tuv), smoothstep(0.38, 0.62, u));
  vec2 d = abs(lq) - halfSize;
  float inside = 1.0 - smoothstep(0.0, 2.0 * px, max(d.x, d.y) * scale);
  vec4 col = mix(gutter, mix(img, gutter, wash), inside);

  float pop = smoothstep(0.03, 0.2, u) * (1.0 - smoothstep(0.38, 0.5, u));
  vec2 corner = portrait ? vec2(1.0, -1.0) : vec2(-1.0, 1.0);
  vec2 bq = q - corner * (halfSize * scale - 0.1);
  if (portrait) bq = bq.yx;
  float r = 0.085 * (0.6 + 0.4 * pop + 0.15 * sin(PI * pop));
  float disc = (1.0 - smoothstep(r - px, r + px, length(bq))) * pop;
  vec2 ta = r * vec2(-0.45, 0.0), tb = r * vec2(-0.12, -0.35), tc = r * vec2(0.48, 0.32);
  float tick = min(segment(bq, ta, tb), segment(bq, tb, tc));
  float mark = 1.0 - smoothstep(0.11 * r - px, 0.11 * r + px, tick);
  return mix(col, mix(badge, gutter, mark), disc);
}
