// Author: gre
// License: MIT
// Description: Small squares in flat colors of the incoming image run out along diagonals, double into bigger squares, then bigger ones, the same motif repeating at every size all over the frame, and the image itself follows with the same march
// Tags: squares, blocks, fractal, grid, math

// @range(16, 96) Cells along the short side of the frame
uniform float cells; // = 32.0
// @range(0, 1) Delay between the flat squares and the incoming image
uniform float spacing; // = 0.5

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  float n = max(cells, 1.0) / min(ratio, 1.0);
  // the nudge keeps cell borders off pixel centers, where rounding differs between targets
  vec2 g = (uv - 0.5) * a * n + 0.003;
  vec2 c = floor(abs(g));
  // past 16 cells from the center the table is mirrored
  vec2 m = mod(c, 32.0);
  vec2 d = min(m, 31.0 - m);
  float v = 0.0, b = 1.0;
  for (int i = 0; i < 4; i++) {
    m = mod(d, 2.0);
    v += b * abs(m.x - m.y);
    d = floor(d * 0.5);
    b *= 2.0;
  }
  v /= 15.0;
  vec2 way = vec2(g.x < 0.0 ? -1.0 : 1.0, g.y < 0.0 ? -1.0 : 1.0);
  vec4 paint = vec4(0.0);
  for (int i = 0; i < 4; i++) {
    vec2 o = vec2(mod(float(i), 2.0), floor(float(i) / 2.0)) + 0.5;
    paint += 0.25 * premultiply(getToColor(clamp(way * (floor(c / 2.0) * 2.0 + o) / n / a + 0.5, 0.0, 1.0)));
  }
  vec2 f = abs(abs(g) - c - 0.5);
  float r = max(f.x, f.y);
  float lag = mix(0.1, 0.5, spacing);
  float run = 0.92 - lag;
  vec4 col = premultiply(getFromColor(uv));
  for (int i = 0; i < 2; i++) {
    float t = smoothstep(0.0, 0.08, progress - lag * float(i) - run * v);
    vec4 next = i == 0 ? paint : premultiply(getToColor(uv));
    col = mix(col, next, clamp((0.56 * t - r) / 0.05, 0.0, 1.0));
  }
  return vec4(col.rgb / max(col.a, 1e-5), col.a);
}
