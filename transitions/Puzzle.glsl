// Author: gre
// License: MIT
// Description: The image is cut into jigsaw puzzle pieces that lift one after another and fall away, revealing the incoming image
// Tags: tiles, shadow, rotate, fragments

// @range(2, 12) Number of pieces across the shorter side
uniform float pieces; // = 5.0
// @range(0, 1) Darkness of the shadows of the lifted pieces
uniform float shadow; // = 0.6

// Hash of a cell, without sin, in [0, 1)
float hash(vec2 c) {
  vec2 p = fract(c * vec2(0.1031, 0.1030));
  p += dot(p, p.yx + 33.33);
  return fract((p.x + p.y) * p.x);
}

float boxDist(vec2 p, vec2 halfSize) {
  vec2 q = abs(p) - halfSize;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// Signed distance of a point, relative to the center of piece c, to that piece (cell units).
// Each edge has a knob (a round head on a neck): a tab for one piece, a blank for its neighbor; border edges are flat.
float pieceDist(vec2 p, vec2 c, vec2 grid, float aspect) {
  vec2 halfSize = vec2(0.5 * aspect, 0.5);
  float d = boxDist(p, halfSize);
  float tabs = 1e3;
  for (int e = 0; e < 4; e++) {
    // right, left, top, bottom: the edge key is the cell on its left or below
    vec2 dir = e == 0 ? vec2(1.0, 0.0) : e == 1 ? vec2(-1.0, 0.0) : e == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0);
    vec2 key = c + min(dir, 0.0);
    vec2 next = c + dir;
    if (next.x >= 0.0 && next.y >= 0.0 && next.x < grid.x && next.y < grid.y) {
      float h = hash(key + (e < 2 ? vec2(0.0) : vec2(71.0, 37.0)));
      // the knob points right or up from the key cell when h < 0.5
      bool tab = (h < 0.5) == (dir.x + dir.y > 0.0);
      vec2 out1 = dir * (tab ? 1.0 : -1.0);
      vec2 along = vec2(abs(dir.y), abs(dir.x));
      vec2 edge = dir * halfSize + along * (fract(h * 2.0) - 0.5) * 0.16;
      float k = min(
        length(p - edge - out1 * 0.15) - 0.125,
        boxDist(p - edge - out1 * 0.06, abs(dir) * 0.08 + along * 0.085));
      if (tab) tabs = min(tabs, k);
      else d = max(d, -k);
    }
  }
  return min(d, tabs);
}

vec4 transition(vec2 uv) {
  // a grid of nearly square cells that fits the frame exactly
  float rows = ratio < 1.0 ? floor(pieces / ratio + 0.5) : pieces;
  float cols = ratio < 1.0 ? pieces : floor(pieces * ratio + 0.5);
  vec2 grid = vec2(cols, rows);
  float aspect = ratio * rows / cols;
  vec2 g = uv * grid;
  vec2 cell = floor(g);

  const float aa = 0.01; // soft edges, in cells
  float boardSum = 0.0;
  float allSum = 0.0;
  // the two top moving pieces under this point
  float prio1 = -1.0, prio2 = -1.0, cov1 = 0.0, cov2 = 0.0, shade1 = 1.0, shade2 = 1.0;
  vec2 uv1 = uv, uv2 = uv;
  float shadowAll = 0.0;
  float seam = 1.0;
  for (int i = 0; i < 9; i++) {
    vec2 c = cell + vec2(mod(float(i), 3.0), floor(float(i) / 3.0)) - 1.0;
    if (c.x < 0.0 || c.y < 0.0 || c.x >= cols || c.y >= rows) continue;
    vec2 center = c + 0.5;
    vec2 local = (g - center) * vec2(aspect, 1.0);
    float h = hash(c + vec2(13.0, 7.0));
    // diagonal order from the top left, a little shuffled
    float diag = (c.x / max(cols - 1.0, 1.0) + (rows - 1.0 - c.y) / max(rows - 1.0, 1.0)) * 0.5;
    float delay = (diag + 1.2 * (h - 0.5) * diag * (1.0 - diag)) * 0.6;
    float t = clamp((progress - delay) / 0.4, 0.0, 1.0);

    // where the piece was: the board keeps the outgoing image where pieces are still in place
    float d0 = pieceDist(local, c, grid, aspect);
    float w = 1.0 - smoothstep(-aa, aa, d0);
    allSum += w;
    if (t <= 0.0) {
      boardSum += w;
      seam = min(seam, abs(d0));
      continue;
    }
    // lift, then fall away: shrink, spin, drift down and darken
    float lift = smoothstep(0.0, 0.25, t);
    float fall = clamp((t - 0.2) / 0.8, 0.0, 1.0);
    fall *= fall;
    float s = max(1.0 - fall, 0.001);
    float a = (h - 0.5) * 3.0 * fall;
    vec2 off = vec2(0.0, -1.2 * fall);
    mat2 rot = mat2(cos(a), -sin(a), sin(a), cos(a));
    vec2 pl = rot * (local - off) / s;
    float dp = pieceDist(pl, c, grid, aspect);
    float cov = (1.0 - smoothstep(-aa, aa, dp * s)) * min(s * 20.0, 1.0); // fades when tiny
    // darker when falling, and on its edges when lifted
    float shade = (1.0 - 0.5 * fall) * (1.0 - 0.3 * lift * (1.0 - smoothstep(0.0, 0.035, -dp)));
    vec2 puv = (center + pl / vec2(aspect, 1.0)) / grid;
    // soft shadow, offset to the bottom right while lifted
    vec2 sl = rot * (local - off - vec2(0.08, -0.1) * lift) / s;
    float sh = (1.0 - smoothstep(-0.05, 0.12, pieceDist(sl, c, grid, aspect) * s)) * lift * (1.0 - fall) * shadow;
    // the hole it leaves is in its shadow too
    shadowAll = max(shadowAll, max(sh, w * lift * (1.0 - smoothstep(0.2, 0.5, t)) * shadow));
    float prio = delay;
    if (cov > 0.0 && prio > prio1) {
      prio2 = prio1; cov2 = cov1; uv2 = uv1; shade2 = shade1;
      prio1 = prio; cov1 = cov; uv1 = puv; shade1 = shade;
    } else if (cov > 0.0 && prio > prio2) {
      prio2 = prio; cov2 = cov; uv2 = puv; shade2 = shade;
    }
  }
  vec4 base = mix(getToColor(uv), getFromColor(uv), boardSum / max(allSum, 0.001));
  // the cuts show on the board as the transition starts
  base.rgb *= (1.0 - shadowAll) * (1.0 - 0.4 * smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.0, 0.015, seam)));
  vec4 p2 = getFromColor(uv2);
  p2.rgb *= shade2;
  vec4 p1 = getFromColor(uv1);
  p1.rgb *= shade1;
  return mix(mix(base, p2, cov2), p1, cov1);
}
