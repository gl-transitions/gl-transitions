// Author: gre
// License: MIT
// Description: Square blocks switch to the incoming image one after another along a rectangular spiral, from the border inward or from the center outward
// Tags: wipe, grid, blocks, spiral

// @param Number of blocks (columns, rows)
uniform ivec2 grid; // = ivec2(8, 6)
// @param Spiral from the top left corner inward; false spirals from the center outward, ending at the top left corner
uniform bool inward; // = true
// @param Turn clockwise; false turns counterclockwise
uniform bool clockwise; // = true
// @range(0, 0.5) Duration of each block's fade, as a fraction of the transition
uniform float smoothness; // = 0.05

// Position of the cell c (from the top left corner) along the spiral that runs clockwise
// from the top left corner of a n.x by n.y grid inward, from 0 to n.x * n.y - 1
float spiralIndex(vec2 c, vec2 n) {
  // ring: distance to the border, in cells
  float k = min(min(c.x, c.y), min(n.x - 1.0 - c.x, n.y - 1.0 - c.y));
  // size of the ring, and the cell's position in it
  vec2 s = n - 2.0 * k;
  vec2 l = c - k;
  // the outer rings come first
  float before = n.x * n.y - s.x * s.y;
  float along;
  if (l.y == 0.0) along = l.x; // top side, to the right
  else if (l.x == s.x - 1.0) along = s.x - 1.0 + l.y; // right side, down
  else if (l.y == s.y - 1.0) along = 2.0 * s.x + s.y - 3.0 - l.x; // bottom side, to the left
  else along = 2.0 * (s.x - 1.0) + 2.0 * (s.y - 1.0) - l.y; // left side, up
  return before + along;
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  vec2 n = max(vec2(grid), vec2(1.0));
  // the cell, counted from the top left corner
  vec2 c = min(floor(vec2(uv.x, 1.0 - uv.y) * n), n - 1.0);
  // the transposed spiral turns the other way from the same corner; walking the spiral
  // outward reverses it too
  if (clockwise != inward) {
    c = c.yx;
    n = n.yx;
  }
  float count = n.x * n.y;
  float i = spiralIndex(c, n);
  if (!inward) i = count - 1.0 - i;

  // the blocks switch one after another, each one fading in over w blocks of time, the first
  // fade starting at 0 and the last ending at 1; without fade, block i switches at (i + 0.5) / count
  float w = max(smoothness, 0.0) * count;
  float o = max(0.5 * (1.0 - w), 0.0);
  float x = progress * (count - 1.0 + 2.0 * o + w) - i - o;
  float m = w > 0.0 ? smoothstep(0.0, w, x) : step(0.0, x);

  if (m <= 0.0) return getFromColor(uv);
  if (m >= 1.0) return getToColor(uv);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  // mixed premultiplied, so transparent images do not bleed their color
  vec4 col = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
