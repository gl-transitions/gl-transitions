// Author: gre
// License: MIT
// Description: The picture becomes a sliding tile puzzle: one tile is lifted out, the empty slot wanders through the grid as each neighbouring tile slides into it and turns over to show its part of the incoming picture, then the missing tile drops back in
// Tags: tiles, puzzle, grid, slide, flip, game

// @range(0, 0.03) Width of the grooves between the tiles, in fractions of the frame's short side
uniform float groove; // = 0.012
// @color Color of the empty slot and of the grooves
uniform vec4 tray; // = vec4(0.12, 0.12, 0.12, 1.0)

const vec2 GRID = vec2(4.0, 3.0);
const float STEPS = 13.0;

// Hamiltonian path of the empty slot through the 4x3 grid (cell = row * 4 + column).
float pathCell(float k) {
  vec4 v = k < 4.0 ? vec4(5.0, 1.0, 0.0, 4.0) : (k < 8.0 ? vec4(8.0, 9.0, 10.0, 6.0) : vec4(2.0, 3.0, 7.0, 11.0));
  float i = mod(k, 4.0);
  return i < 0.5 ? v.x : (i < 1.5 ? v.y : (i < 2.5 ? v.z : v.w));
}

vec2 cellPos(float id) {
  return vec2(mod(id, GRID.x), floor(id / GRID.x));
}

float pathIndex(float id) {
  float r = 0.0;
  for (int k = 0; k < 12; k++) {
    if (abs(pathCell(float(k)) - id) < 0.5) r = float(k);
  }
  return r;
}

// The grid runs along the long side, so portrait frames use it transposed.
vec2 frameUv(vec2 g) {
  vec2 p = g / GRID;
  return ratio < 1.0 ? p.yx : p;
}

vec4 emptySlot(vec2 q, vec2 cellSize) {
  vec2 d = min(q, 1.0 - q) * cellSize;
  float shade = smoothstep(0.0, 0.05, min(d.x, d.y));
  return vec4(tray.rgb * mix(0.42, 1.0, shade), tray.a);
}

vec4 tile(vec4 c, vec2 q, vec2 cellSize, float g, float lit) {
  vec2 d = min(q, 1.0 - q) * cellSize;
  float e = min(d.x, d.y);
  float env = clamp(g / 0.012, 0.0, 1.0);
  float a = mix(1.0, clamp((e - g * 0.5) / 0.003 + 0.5, 0.0, 1.0), env);
  c.rgb *= lit * (1.0 - 0.25 * env * (1.0 - smoothstep(g * 0.5, g * 0.5 + 0.012, e)));
  return mix(vec4(tray.rgb * 0.42, tray.a), c, a);
}

bool inside(vec2 q) {
  return all(greaterThanEqual(q, vec2(0.0))) && all(lessThanEqual(q, vec2(1.0)));
}

vec4 transition(vec2 uv) {
  vec2 st = ratio < 1.0 ? uv.yx : uv;
  vec2 cellSize = vec2(max(ratio, 1.0 / ratio), 1.0) / GRID;
  float g = groove * smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.96, 1.0, progress));
  float T = progress * STEPS;
  float s = floor(T);
  float f = smoothstep(0.08, 0.92, T - s);

  vec2 cell = min(floor(st * GRID), GRID - 1.0);
  vec2 q = st * GRID - cell;
  float j = pathIndex(cell.y * GRID.x + cell.x);

  vec4 col;
  if (j > s) col = tile(getFromColor(uv), q, cellSize, g, 1.0);
  else if (j + 1.0 < s) col = tile(getToColor(uv), q, cellSize, g, 1.0);
  else col = emptySlot(q, cellSize);

  if (s < 0.5) {
    vec2 c0 = cellPos(pathCell(0.0));
    float k = 1.0 - f;
    vec2 lq = (st * GRID - c0 - 0.5) / max(k, 1e-4) + 0.5;
    if (inside(lq)) col = tile(getFromColor(frameUv(c0 + lq)), lq, cellSize * k, g, 1.0 + 0.3 * f);
  } else if (s < 11.5) {
    vec2 src = cellPos(pathCell(s));
    vec2 dst = cellPos(pathCell(s - 1.0));
    float x = T - s;
    vec2 lq = st * GRID - mix(src, dst, smoothstep(0.0, 0.6, x));
    if (inside(lq)) {
      // once in place, the tile turns over about the axis across its motion; its back is the incoming picture
      vec2 ax = abs(dst - src);
      float cs = cos(3.14159265 * smoothstep(0.45, 1.0, x));
      float along = dot(lq - 0.5, ax);
      float u = along / max(abs(cs), 1e-4);
      if (abs(u) <= 0.5) {
        vec2 tq = lq + ax * ((cs > 0.0 ? u : -u) - along);
        vec4 c = cs > 0.0 ? getFromColor(frameUv(src + tq)) : getToColor(frameUv(dst + tq));
        col = tile(c, tq, cellSize, g, 0.55 + 0.45 * abs(cs));
      }
    }
  } else if (s < 12.5) {
    vec2 cl = cellPos(pathCell(11.0));
    float k = mix(1.25, 1.0, f);
    vec2 lq = (st * GRID - cl - 0.5) / k + 0.5;
    if (inside(lq)) col = mix(col, tile(getToColor(frameUv(cl + lq)), lq, cellSize * k, g, 1.0), f);
  }
  return col;
}
