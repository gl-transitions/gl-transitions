// Author: gre
// License: MIT
// Description: The incoming picture loads over the outgoing one in passes, like a progressive image on a slow connection: gray blocks scan down the frame, then the blocks take their colors, then smooth into blurry gradients, and a last scan brings the full detail
// Tags: pixel, blocks, loading, digital, retro

// @range(6, 40, 1) Number of block rows down the frame
uniform int blocks; // = 18

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float decoded(float row, float rows, float start, float dur) {
  return step(row + 1.0, floor(clamp((progress - start) / dur, 0.0, 1.0) * (rows + 0.999)));
}

vec4 transition(vec2 uv) {
  float rows = max(float(blocks), 1.0);
  vec2 grid = vec2(max(floor(rows * ratio + 0.5), 1.0), rows);
  vec2 bs = 1.0 / grid;
  vec2 cell = min(floor(vec2(uv.x, 1.0 - uv.y) * grid), grid - 1.0);
  vec2 org = vec2(cell.x * bs.x, 1.0 - (cell.y + 1.0) * bs.y);
  vec2 f = (uv - org) / bs;

  vec4 a = getToColor(org + bs * vec2(0.25, 0.25));
  vec4 b = getToColor(org + bs * vec2(0.75, 0.25));
  vec4 c = getToColor(org + bs * vec2(0.25, 0.75));
  vec4 d = getToColor(org + bs * vec2(0.75, 0.75));
  vec4 dc = 0.25 * (a + b + c + d);
  // extrapolating the in-block gradient to the block edges keeps the seams between blocks visible
  vec2 w = clamp(f * 2.0 - 0.5, -0.5, 1.5);
  vec4 lo = clamp(mix(mix(a, b, w.x), mix(c, d, w.x), w.y), 0.0, 1.0);

  float s0 = decoded(cell.y, rows, 0.02, 0.32);
  float s1 = decoded(cell.y, rows, 0.34, 0.2);
  float s2 = decoded(cell.y, rows, 0.54, 0.2);
  float s3 = decoded(cell.y, rows, 0.74, 0.24);

  vec4 col = getFromColor(uv);
  col = mix(col, vec4(vec3(luma(dc.rgb)), dc.a), s0);
  col = mix(col, dc, s1);
  col = mix(col, lo, s2);
  return mix(col, getToColor(uv), s3);
}
