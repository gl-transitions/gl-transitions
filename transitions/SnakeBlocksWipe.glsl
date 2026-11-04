// Author: gre
// License: MIT
// Description: Blocks switch to the incoming image one at a time, row after row from the top (or column after column from the left), each line running the opposite way to the one before, like a snake winding across the frame
// Tags: wipe, blocks, grid, zigzag

// @param Number of blocks (columns, rows)
uniform ivec2 grid; // = ivec2(8, 6)
// @param Wind down the columns instead of along the rows
uniform bool vertical; // = false
// @range(0, 4) How long each block takes to fade in, in turns of one block (0 switches it at once)
uniform float smoothness; // = 0.5

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  vec2 g = max(vec2(grid), 1.0);
  // block coordinates from the top left corner
  vec2 cell = min(floor(vec2(uv.x, 1.0 - uv.y) * g), g - 1.0);
  // the snake runs along the rows, or along the columns when vertical
  float lines = vertical ? g.x : g.y;
  float len = vertical ? g.y : g.x;
  float line = vertical ? cell.x : cell.y;
  float pos = vertical ? cell.y : cell.x;
  // every other line runs backward
  if (mod(line, 2.0) > 0.5) pos = len - 1.0 - pos;
  float order = line * len + pos;

  // block k fades in from k to k + w, on a timeline from 0 to n - 1 + w
  float n = lines * len;
  float w = max(smoothness, 0.001);
  float m = clamp((progress * (n - 1.0 + w) - order) / w, 0.0, 1.0);

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
