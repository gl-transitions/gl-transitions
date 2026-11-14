// Author: gre
// License: MIT
// Description: The frame is cut into tiles that swap places in pairs, round after round along the rows then along the columns, one tile of each pair lifting to swing over the other with a soft shadow; each tile turns to the incoming image during one of its swaps, so the incoming picture arrives scrambled and the last rounds sort it out
// Tags: tiles, grid, shuffle, swap, slide, puzzle, shadow

// @range(2, 8, 1) Number of tiles along the longer side of the frame (the tiles stay about square)
uniform int tiles; // = 5
// @range(0, 0.15) Width of the gaps that open between the tiles, as a part of a tile
uniform float gap; // = 0.05
// @range(0, 1) Darkness of the shadows the tiles cast
uniform float shadow; // = 0.55
// @color Color of the tray seen under the tiles
uniform vec4 tray; // = vec4(0.07, 0.07, 0.08, 1.0)

// tiles per side, at most
const float MAX_TILES = 8.0;
// rounds of swaps, along the rows in even rounds and along the columns in odd ones
const int ROUNDS = 4;
// the gaps open over [0, OPEN] and close over [1 - OPEN, 1]
const float OPEN = 0.15;
// the swaps run over [START, 1 - START]
const float START = 0.07;
// each round sweeps across the frame from its top left corner, a swap starting WAVE later than the one a cell
// before it, plus up to JITTER, in swap durations. The next round follows 1 + WAVE + JITTER behind, so that
// the rounds overlap without a tile ever starting a swap before it has finished the one before
const float WAVE = 0.4;
const float JITTER = 0.15;
// growth of the lifted tile of a swap and shrink of the other one, as seen in perspective
const float GROW = 0.08;
const float SINK = 0.03;
// how far the tile that slides over swings out of its line, in cells
const float SWING = 0.2;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0015;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// signed distance to a box of half size b with corner radius r, negative inside
float boxDist(vec2 p, vec2 b, float r) {
  vec2 d = abs(p) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// the cell that cell c swaps with in round k (c itself when it has no partner). Each line of the
// round pairs its cells two by two, from its first or from its second cell; a line of two cells
// swaps them in one of its two rounds only, so that the second swap does not undo the first
vec2 partner(vec2 c, float k, vec2 n) {
  bool rows = mod(k, 2.0) < 0.5;
  float a = rows ? c.x : c.y;
  float len = rows ? n.x : n.y;
  float line = rows ? c.y : c.x;
  float par = len < 2.5 ? mod(line + floor(0.5 * k), 2.0) : step(0.5, hash12(vec2(line, 7.0 * k + 1.0)));
  float b = mod(a - par, 2.0) < 0.5 ? a + 1.0 : a - 1.0;
  if (a < par || b >= len) b = a;
  return rows ? vec2(b, c.y) : vec2(c.x, b);
}

bool differ(vec2 a, vec2 b) {
  return abs(a.x - b.x) + abs(a.y - b.y) > 0.5;
}

// time of the swap of cells c and b in round k, from 0 when it starts to 1 when it ends;
// sw is the duration of a swap and the time between two rounds
float swapTime(vec2 c, vec2 b, float k, vec2 n, vec2 sw) {
  vec2 m = 0.5 * (c + b);
  float t0 = START + k * sw.y + sw.x * (WAVE * (m.x + n.y - 1.0 - m.y) + JITTER * hash12(min(c, b) + 13.0 * k));
  return (progress - t0) / sw.x;
}

// the swap of the tile that cell c holds now, the first swap of the cell that is not over yet:
// x its round (ROUNDS once the cell has no swap left), y its time, zw the partner cell
vec4 currentSwap(vec2 c, vec2 n, vec2 sw) {
  vec4 cur = vec4(float(ROUNDS), 0.0, c);
  bool found = false;
  for (int i = 0; i < ROUNDS; i++) {
    float k = float(i);
    if (!found) {
      vec2 b = partner(c, k, n);
      if (differ(b, c)) {
        float u = swapTime(c, b, k, n, sw);
        if (u < 1.0) {
          cur = vec4(k, max(u, 0.0), b);
          found = true;
        }
      }
    }
  }
  return cur;
}

// lift of the tile of cell c during its current swap: positive for the tile that slides over,
// negative for the one that slides under
float swapLift(vec2 c, vec4 cur) {
  if (cur.x >= float(ROUNDS)) return 0.0;
  float u = cur.y;
  float bell = 16.0 * u * u * (1.0 - u) * (1.0 - u);
  bool over = (hash12(min(c, cur.zw) + 13.0 * cur.x + 3.7) < 0.5) == (c.x + c.y < cur.z + cur.w);
  return over ? bell : -bell;
}

// center of that tile, in cells: the tile that slides over swings out a little to pass around the other
vec2 swapPos(vec2 c, vec4 cur, float lift) {
  float u = cur.y;
  float e = u * u * u * (u * (6.0 * u - 15.0) + 10.0);
  vec2 side = (cur.zw - c).yx * (hash12(cur.zw + c + 1.9 * cur.x) < 0.5 ? 1.0 : -1.0);
  return mix(c, cur.zw, e) + 0.5 + SWING * max(lift, 0.0) * side;
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - abs(v));
}

// the color of a tile: its image points src (outgoing xy, incoming zw) turned by w, brightened as it lifts,
// with a pale rim along its edge (at distance e) and darkened by the shadows sh of the tiles above it
vec4 tileColor(vec4 src, float w, float lift, float e, float sh) {
  vec4 c = w <= 0.0 ? getFromColor(mirror(src.xy)) : w >= 1.0 ? getToColor(mirror(src.zw))
    : mix(getFromColor(mirror(src.xy)), getToColor(mirror(src.zw)), w);
  float up = max(lift, 0.0);
  float rim = 0.2 * up * (1.0 - smoothstep(0.0, 0.006, e));
  c.rgb = mix(clamp(c.rgb * (1.0 + 0.06 * up + 0.1 * min(lift, 0.0)) * (1.0 - sh), 0.0, 1.0), vec3(1.0), rim);
  return c;
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  // at least two tiles along each side, so that the tiles move along both
  float nl = clamp(float(tiles), 2.0, MAX_TILES);
  vec2 n = ratio >= 1.0
    ? vec2(nl, clamp(floor(nl / ratio + 0.5), 2.0, MAX_TILES))
    : vec2(clamp(floor(nl * ratio + 0.5), 2.0, MAX_TILES), nl);
  // a cell, and this point, in frame heights
  vec2 cell = vec2(ratio, 1.0) / n;
  vec2 x = uv * vec2(ratio, 1.0);
  vec2 here = clamp(floor(uv * n), vec2(0.0), n - 1.0);
  float open = smoothstep(0.0, OPEN, progress) * (1.0 - smoothstep(1.0 - OPEN, 1.0, progress));
  float g = clamp(gap, 0.0, 0.15) * open * min(cell.x, cell.y);
  // without gaps, the tiles overlap a little to hide their seams
  vec2 hb = vec2(0.5 * cell - 0.5 * g + EDGE * max(1.0 - 0.5 * g / EDGE, 0.0));
  float rad = 0.6 * g;
  // duration of a swap, and time between two rounds: the last swap ends at 1 - START
  float gapK = 1.0 + WAVE + JITTER;
  float sd = (1.0 - 2.0 * START) / (float(ROUNDS - 1) * gapK + 1.0 + WAVE * (n.x + n.y - 2.0) + JITTER);
  vec2 sw = vec2(sd, sd * gapK);

  // the two highest tiles seen here: height, coverage, lift, turn, edge distance, outgoing and incoming image points
  float z1 = -9.0, z2 = -9.0, m1 = 0.0, m2 = 0.0, l1 = 0.0, l2 = 0.0, w1 = 0.0, w2 = 0.0, e1 = 0.0, e2 = 0.0;
  vec4 s1 = vec4(0.0), s2 = vec4(0.0);
  // the tiles that can be seen here are held by the cells nearby
  for (int j = 0; j < 5; j++) {
    for (int i = 0; i < 5; i++) {
      vec2 o = vec2(float(i) - 2.0, float(j) - 2.0);
      vec2 c = here + o;
      if (abs(o.x) + abs(o.y) > 3.5 || c.x < 0.0 || c.y < 0.0 || c.x >= n.x || c.y >= n.y) continue;
      vec4 cur = currentSwap(c, n, sw);
      float lift = swapLift(c, cur);
      float sc = 1.0 + GROW * max(lift, 0.0) - SINK * max(-lift, 0.0);
      // this point in the tile, from its center, scaled back to its size at rest
      vec2 q = (x - swapPos(c, cur, lift) * cell) / sc;
      float e = -boxDist(q, hb, rad) * sc;
      float cov = clamp(e / EDGE + 0.5, 0.0, 1.0);
      // where resting tiles overlap at their edges, the one that covers this point fully comes first
      float z = lift + 0.001 * cov;
      if (cov <= 0.0 || z <= z2) continue;
      // the cell the tile started from, the one it ends in, and its swaps before and from the current one
      vec2 s = c, h = c;
      float before = 0.0, after = 0.0;
      for (int k = ROUNDS - 1; k >= 0; k--) {
        if (float(k) < cur.x) {
          vec2 b = partner(s, float(k), n);
          if (differ(b, s)) before += 1.0;
          s = b;
        }
      }
      for (int k = 0; k < ROUNDS; k++) {
        if (float(k) >= cur.x) {
          vec2 b = partner(h, float(k), n);
          if (differ(b, h)) after += 1.0;
          h = b;
        }
      }
      // each tile turns to the incoming image during one of its swaps, so the incoming image comes
      // scrambled and the last rounds sort it out; a tile that never moves turns in place at the end
      float turn = floor(hash12(h + 21.3) * (before + after));
      float w = before + after < 0.5 ? smoothstep(1.0 - 2.0 * OPEN, 1.0 - START, progress)
        : before > turn ? 1.0 : before == turn ? smoothstep(0.35, 0.65, cur.y) : 0.0;
      vec2 l = q / cell + 0.5;
      vec4 src = vec4((s + l) / n, (h + l) / n);
      if (z > z1) {
        z2 = z1; m2 = m1; l2 = l1; w2 = w1; e2 = e1; s2 = s1;
        z1 = z; m1 = cov; l1 = lift; w1 = w; e1 = e; s1 = src;
      } else {
        z2 = z; m2 = cov; l2 = lift; w2 = w; e2 = e; s2 = src;
      }
    }
  }

  // shadows cast on the tray and on the two tiles by the tiles above them, longer and softer as they lift
  float sh0 = 0.0, sh1 = 0.0, sh2 = 0.0;
  vec2 light = vec2(0.45, -0.75) * min(cell.x, cell.y);
  for (int j = 0; j < 5; j++) {
    for (int i = 0; i < 5; i++) {
      vec2 o = vec2(float(i) - 2.0, float(j) - 2.0);
      vec2 c = here + o;
      if (abs(o.x) + abs(o.y) > 3.5 || c.x < 0.0 || c.y < 0.0 || c.x >= n.x || c.y >= n.y) continue;
      vec4 cur = currentSwap(c, n, sw);
      float lift = swapLift(c, cur);
      float up = max(lift, 0.0);
      vec2 d = x - swapPos(c, cur, lift) * cell - light * (0.15 * g / min(cell.x, cell.y) + 0.06 * up);
      float blur = 0.003 + 0.25 * g + 0.04 * up * min(cell.x, cell.y);
      float sdist = boxDist(d, hb * (1.0 + GROW * up - SINK * max(-lift, 0.0)), rad);
      float a = (1.0 - smoothstep(-blur, blur, sdist)) * (0.75 - 0.25 * up);
      sh0 = max(sh0, a);
      if (lift > z2 + 0.01) sh2 = max(sh2, a);
      if (lift > z1 + 0.01) sh1 = max(sh1, a);
    }
  }

  float k = clamp(shadow, 0.0, 1.0);
  vec4 col = vec4(tray.rgb * (1.0 - k * sh0), tray.a);
  // the lower tile only shows where the top one does not cover this point fully
  if (m2 > 0.0 && m1 < 1.0) col = mix(col, tileColor(s2, w2, l2, e2, k * sh2), m2);
  if (m1 > 0.0) col = mix(col, tileColor(s1, w1, l1, e1, k * sh1), m1);
  return col;
}
