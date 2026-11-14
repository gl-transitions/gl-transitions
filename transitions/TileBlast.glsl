// Author: gre
// License: MIT
// Description: The outgoing image breaks into square tiles that blast toward the viewer from a point, the nearest ones first, each one tumbling and growing in perspective as it flies out past the frame, uncovering the incoming image behind them
// Tags: 3d, tiles, explode, fragments

// @range(3, 12, 1) Number of rows of tiles
uniform int rows; // = 6
// @param Point the tiles blast away from, in texture coordinates
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 1) How much the tiles spin and tumble as they fly
uniform float spin; // = 0.6
// @range(0, 1) How much the tiles darken as they turn from the light, and the shadows they cast
uniform float shading; // = 0.6

// distance of the eye, and depth reached by a tile at the end of its flight, in frame heights
const float EYE = 2.0;
const float ZEND = 1.6;
// how far a tile drifts away from the blast point while it flies, in frame heights
const float DRIFT = 0.3;
// a tile leaves after WAVE times its distance to the blast point (plus up to JITTER) and flies for FLIGHT,
// or faster after FINAL so that every tile is gone at the end
const float WAVE = 0.75;
const float JITTER = 0.06;
const float FLIGHT = 0.45;
const float FINAL = 0.75;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0015;
// direction toward the light, upper left, and the half vector between it and the eye
const vec3 L = vec3(-0.32, 0.4, 0.86);
const vec3 HV = vec3(-0.1659, 0.2073, 0.9641);

vec4 hash4(vec2 p) {
  vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  q += dot(q, q.wzxy + 33.33);
  return fract((q.xxyz + q.yzzw) * q.zywx);
}

// how far the tile of cell g is along its flight, 0 at rest to 1 gone: a kick, then it speeds up toward the eye
float flight(vec2 g, vec2 size, vec2 c, float dmax) {
  // the tiles around the blast point leave first, right at the start, and the farthest ones last
  float d = clamp((length((g + 0.5) * size - c) - 0.7 * size.y) / dmax, 0.0, 1.0);
  float t = (progress - WAVE * d - JITTER * hash4(g).x) / FLIGHT;
  t = clamp(max(t, (progress - FINAL) / (1.0 - FINAL)), 0.0, 1.0);
  return t * (0.55 + 0.45 * t);
}

// the unit direction the tile of cell g flies along, away from the blast point
vec2 flyDir(vec2 g, vec2 size, vec2 c) {
  vec2 v = (g + 0.5) * size - c;
  float l = length(v);
  // a tile right on the blast point flies off in a direction of its own
  vec2 a = 6.2831853 * hash4(g + 7.0).xy;
  return l > 0.02 * size.y ? v / l : vec2(cos(a.x), sin(a.x));
}

// Rodrigues rotation of v around the unit axis k, by the angle of cosine cb and sine sb
vec3 turn(vec3 v, vec3 k, float cb, float sb) {
  return v * cb + cross(k, v) * sb + k * dot(k, v) * (1.0 - cb);
}

vec4 transition(vec2 uv) {
  vec2 aspect = vec2(ratio, 1.0);
  vec2 P = uv * aspect;
  vec2 c = clamp(center, 0.0, 1.0) * aspect;
  float n = clamp(float(rows), 1.0, 12.0);
  vec2 grid = vec2(max(1.0, floor(ratio * n + 0.5)), n);
  vec2 size = aspect / grid;
  // from the blast point to the farthest tile center, beyond the tiles that leave first
  float dmax = max(length(max(c, aspect - c) - 0.5 * size) - 0.7 * size.y, 1e-3);
  float spinAmt = clamp(spin, 0.0, 1.0);
  float shadeAmt = clamp(shading, 0.0, 1.0);
  vec3 eye = vec3(c, EYE);
  vec3 ray = vec3(P - c, -EYE);

  // the two nearest tiles seen here: depth, cell, image point, coverage, shading
  float z1 = 1e9, z2 = 1e9;
  vec2 g1 = vec2(-1e4), g2 = vec2(-1e4);
  vec2 q1 = P, q2 = P;
  float m1 = 0.0, m2 = 0.0, s1 = 1.0, s2 = 1.0;
  float lift1 = 0.0, lift2 = 0.0;

  // march along the flight: for each step, find where a tile seen here at that step would have started,
  // first along the line from the blast point, then along the flight of the tile found there,
  // and test the 2x2 cells nearest to it
  // the steps move the start point by less than half a tile
  float dw = max(0.4 * size.y / (length(P - c) * ZEND / EYE + DRIFT), 1.0 / 31.0);
  vec2 lastCell = vec2(-1e4), lastSide = vec2(0.0);
  for (int k = 0; k < 32; k++) {
    float wk = float(k) * dw;
    if (wk > 1.0 + dw) break;
    wk = min(wk, 1.0);
    vec2 back = c + (P - c) * (EYE - ZEND * wk) / EYE;
    vec2 home = back - DRIFT * wk * flyDir(floor(back / size), size, c);
    home = back - DRIFT * wk * flyDir(floor(home / size), size, c);
    vec2 f = home / size;
    vec2 cell = floor(f);
    vec2 side = step(0.5, fract(f)) * 2.0 - 1.0;
    // consecutive steps often land on the same cells
    if (cell == lastCell && side == lastSide) continue;
    lastCell = cell;
    lastSide = side;
    for (int j = 0; j < 4; j++) {
      vec2 g = cell + vec2(j == 1 || j == 3 ? side.x : 0.0, j >= 2 ? side.y : 0.0);
      if (g.x < 0.0 || g.y < 0.0 || g.x >= grid.x || g.y >= grid.y) continue;
      if (g == g1 || g == g2) continue;
      float u = flight(g, size, c, dmax);
      if (u >= 1.0) continue;
      vec4 h = hash4(g + 31.0);
      vec2 dir = flyDir(g, size, c);
      vec2 h0 = (g + 0.5) * size;
      vec3 tc = vec3(h0 + dir * DRIFT * u, ZEND * u);
      // a spin in the frame, then a tumble around an axis across the flight
      float a = spinAmt * 2.4 * (h.x - 0.5) * u;
      float b = spinAmt * (0.5 + 0.7 * h.y) * (h.z < 0.5 ? -1.0 : 1.0) * 1.8 * u;
      vec3 ax = normalize(vec3(-dir.y + 0.4 * (h.w - 0.5), dir.x, 0.0));
      float ca = cos(a), sa = sin(a), cb = cos(b), sb = sin(b);
      vec3 a1 = turn(vec3(ca, sa, 0.0), ax, cb, sb);
      vec3 a2 = turn(vec3(-sa, ca, 0.0), ax, cb, sb);
      vec3 nrm = turn(vec3(0.0, 0.0, 1.0), ax, cb, sb);
      float den = dot(ray, nrm);
      if (abs(den) < 1e-5) continue;
      float lam = dot(tc - eye, nrm) / den;
      if (lam <= 0.0 || lam >= z2) continue;
      vec3 hit = eye + lam * ray - tc;
      vec2 l = vec2(dot(hit, a1), dot(hit, a2));
      // anti-aliased edges, scaled to the screen; at rest the edges are hard, so that the tiles join without seams
      vec2 box = 0.5 * size - abs(l);
      float e = min(box.x, box.y) * EYE / (EYE - tc.z) * max(abs(nrm.z), 0.15);
      float m = clamp(e / (2.0 * EDGE) + 0.5 + 0.5 * (1.0 - smoothstep(0.0, 0.06, u)), 0.0, 1.0);
      if (m <= 0.0) continue;
      // lit from the upper left, with a pale rim and a glint as a tile faces the light; unchanged at rest
      vec3 nf = den < 0.0 ? nrm : -nrm;
      float lit = 1.0 - 0.6 * shadeAmt * (1.0 - clamp(dot(nf, L) / L.z, 0.0, 1.0));
      float lift = smoothstep(0.0, 0.15, u);
      lit += shadeAmt * lift * (0.2 * pow(max(dot(nf, HV), 0.0), 60.0) + 0.3 * (1.0 - smoothstep(0.0, 0.003, e)));
      if (den >= 0.0) lit *= 0.55;
      if (lam < z1) {
        z2 = z1; g2 = g1; q2 = q1; m2 = m1; s2 = s1; lift2 = lift1;
        z1 = lam; g1 = g; q1 = h0 + l; m1 = m; s1 = lit; lift1 = lift;
      } else {
        z2 = lam; g2 = g; q2 = h0 + l; m2 = m; s2 = lit; lift2 = lift;
      }
    }
  }

  // soft shadows of the tiles that have just lifted, on the incoming image and the tiles below them
  float shTo = 0.0, sh1 = 0.0, sh2 = 0.0;
  if (shadeAmt > 0.0) {
    vec2 base = floor(P / size);
    for (int y = -1; y <= 1; y++) {
      for (int x = -1; x <= 1; x++) {
        vec2 g = base + vec2(float(x), float(y));
        if (g.x < 0.0 || g.y < 0.0 || g.x >= grid.x || g.y >= grid.y) continue;
        float u = flight(g, size, c, dmax);
        float z = ZEND * u;
        // the shadow fades before it can reach beyond the next tile
        float w = smoothstep(0.0, 0.03, u) * (1.0 - smoothstep(0.1 * size.y, 0.7 * size.y, z));
        if (w <= 0.0) continue;
        vec2 o = P + L.xy / L.z * z - ((g + 0.5) * size + flyDir(g, size, c) * DRIFT * u);
        float blur = 0.004 + 0.25 * z;
        vec2 sb = 0.5 * size - abs(o) + 0.5 * blur;
        float sh = smoothstep(0.0, blur, sb.x) * smoothstep(0.0, blur, sb.y) * w;
        // a tile casts no shadow on itself
        shTo = max(shTo, sh);
        if (g != g1) sh1 = max(sh1, sh);
        if (g != g2) sh2 = max(sh2, sh);
      }
    }
  }
  float dark = 0.5 * shadeAmt;

  // the incoming image settles back from a slight zoom, a little dimmed while the tiles fly
  float settle = 1.0 - progress;
  vec2 tq = c + (P - c) / (1.0 + 0.06 * settle * settle);
  vec4 col = getToColor(tq / aspect);
  col.rgb *= (1.0 - dark * shTo) * (1.0 - 0.25 * shadeAmt * (1.0 - smoothstep(0.2, 0.9, progress)));
  if (m2 > 0.0) {
    vec4 img = getFromColor(clamp(q2 / aspect, 0.0, 1.0));
    img.rgb *= s2 * mix(1.0 - dark * sh2, 1.0, lift2);
    col = mix(col, img, m2);
  }
  if (m1 > 0.0) {
    vec4 img = getFromColor(clamp(q1 / aspect, 0.0, 1.0));
    img.rgb *= s1 * mix(1.0 - dark * sh1, 1.0, lift1);
    col = mix(col, img, m1);
  }
  return col;
}
