// Author: gre
// License: MIT
// Description: The frame becomes a split-flap board: in each cell the top half of the outgoing image flips down on a hinge across the middle, cell after cell, its back bringing the bottom half of the incoming image
// Tags: 3d, flip, grid

// @param Number of cells (columns, rows)
uniform ivec2 size; // = ivec2(8, 6)
// @range(0, 0.9) Delay of the last cell's flip, as a part of the transition
uniform float stagger; // = 0.6
// @range(0, 1) How much the order of the cells is shuffled, from a wave across the board to random
uniform float randomness; // = 0.3
// @range(1, 4, 1) Number of flaps that fall in each cell, the ones before the last showing other parts of the incoming image
uniform int flaps; // = 1
// @range(0, 0.05) Width of the gaps between the cells, as a part of the frame's shorter side (the hinges get half of it)
uniform float gap; // = 0.004
// @range(0, 1) Amount of perspective: the falling flaps grow as they come toward the viewer
uniform float perspective; // = 0.35
// @range(0, 1) How much the flaps darken as they turn away from the light, and the shadows they cast
uniform float shading; // = 0.4
// @color Color seen in the gaps between the cells
uniform vec4 background; // = vec4(0.0, 0.0, 0.0, 1.0)

const float PI = 3.141592653589793;
// width of the anti-aliased edges, as a part of the frame's shorter side
const float EDGE = 0.001;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// the cell's flip, 0 to 1
float cellTime(vec2 cell, vec2 grid) {
  float wave = (cell.x + 0.5 * (grid.y - 1.0 - cell.y)) / max(grid.x - 1.0 + 0.5 * (grid.y - 1.0), 1.0);
  float order = mix(wave, hash12(cell + 17.0), randomness);
  float delay = clamp(stagger, 0.0, 0.99);
  return clamp((progress - order * delay) / (1.0 - delay), 0.0, 1.0);
}

// the card on the front of the falling flap, at the cell's flip t
float flapIndex(float t, float n) {
  return min(floor(t * n), n - 1.0);
}

// the falling flap's angle, 0 upright to PI down: it starts gently and lands fast
float flapAngle(float t, float n) {
  float u = t * n - flapIndex(t, n);
  return PI * u * (0.3 + 0.7 * u);
}

// card i of a cell at the point lc of the card: the outgoing image first, the incoming one last,
// and in between the incoming image of another cell
vec4 card(float i, float n, vec2 cell, vec2 grid, vec2 lc) {
  if (i < 0.5) return getFromColor((cell + lc) / grid);
  vec2 src = cell;
  if (i < n - 0.5) src = floor(vec2(hash12(cell * 3.7 + i * 11.3), hash12(cell * 5.3 + i * 7.9 + 1.7)) * grid);
  return getToColor((src + lc) / grid);
}

// 1 inside a half card, 0 in the gaps: x across the card and f the distance from the hinge, in cell sizes
float cardMask(float x, float f, vec2 cellSize, float g) {
  if (g <= 0.0) return 1.0;
  float e = EDGE * min(1.0, g / max(gap, 1e-4));
  // the gap at the hinge is half as wide as the one between the cells
  float d = min(min(x, 1.0 - x) * cellSize.x, min(2.0 * f, 0.5 - f) * cellSize.y);
  return smoothstep(0.5 * g - e, 0.5 * g + e, d);
}

vec4 transition (vec2 uv) {
  vec2 grid = max(vec2(size), 1.0);
  float n = max(float(flaps), 1.0);
  vec2 cellSize = vec2(ratio, 1.0) / grid / min(ratio, 1.0);
  vec2 cell = floor(uv * grid);
  vec2 l = uv * grid - cell;
  // the gaps open at the start and close at the end
  float g = gap * smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
  // w: height above the hinge, in cell heights
  float w = l.y - 0.5;
  bool upper = w >= 0.0;

  // the board behind the falling flaps: the top half of the next card once the flap has left it,
  // the bottom half of the current card until the flap has landed on it
  float t = cellTime(cell, grid);
  float k = flapIndex(t, n);
  float a = flapAngle(t, n);
  bool started = t * n > k;
  bool landed = t >= 1.0;
  vec4 color = card(k + (upper ? (started ? 1.0 : 0.0) : (landed ? 1.0 : 0.0)), n, cell, grid, l);
  // shadows of the flap leaning over the top half, then falling onto the bottom half
  if (started && !landed) color.rgb *= 1.0 - 0.45 * shading * max(upper ? cos(a) : -cos(a), 0.0);
  color = mix(background, color, cardMask(l.x, abs(w), cellSize, g));

  // the falling flaps of this cell and of its neighbors, which grow beyond their cells as they come closer
  float nearest = -1.0;
  for (int d = -1; d <= 1; d++) {
    vec2 nc = cell + vec2(float(d), 0.0);
    if (nc.x < 0.0 || nc.x > grid.x - 1.0) continue;
    float nt = d == 0 ? t : cellTime(nc, grid);
    float na = d == 0 ? a : flapAngle(nt, n);
    float fc = cos(na);
    float fs = sin(na);
    // a point at distance f from the hinge is at height f * fc and depth f * fs, nearer points look wider
    if (abs(fc) < 1e-5 || (w >= 0.0) != (fc > 0.0)) continue;
    float f = w / fc;
    if (f > 0.5) continue;
    float z = f * fs;
    if (z <= nearest) continue;
    float lx = 0.5 + (l.x - float(d) - 0.5) * (1.0 - perspective * z);
    if (lx < 0.0 || lx > 1.0) continue;
    bool front = fc > 0.0;
    vec2 lc = vec2(lx, front ? 0.5 + f : 0.5 - f);
    float m = cardMask(lx, f, cellSize, g);
    if (m <= 0.0) continue;
    vec4 img = card(flapIndex(nt, n) + (front ? 0.0 : 1.0), n, nc, grid, lc);
    // lit from above the viewer: the front darkens as it turns down, the back brightens as it lands
    float lambert = (front ? 0.92 * fc - 0.4 * fs : 0.4 * fs - 0.92 * fc) / 0.92;
    img.rgb *= mix(1.0 - shading, 1.0, clamp(lambert, 0.0, 1.0));
    color = mix(color, img, m);
    nearest = z;
  }
  return color;
}
