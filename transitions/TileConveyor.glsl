// Author: gre
// License: MIT
// Description: Gaps open between the tiles of the outgoing image over a track that winds through every tile; the tiles glide along it like a train, the outgoing ones leaving at the bottom right while the incoming ones enter at the bottom left and wind through the frame until they settle in place
// Tags: grid, tiles, geometric, slide

// @range(1, 3, 1) Size of the track: 2 to the power of order tiles along each side
uniform int order; // = 2
// @range(0.05, 0.4) Width of the gaps between the tiles, as a part of a tile
uniform float gap; // = 0.26
// @range(0, 1) Strength of the bevel and of the shadow the tiles cast on the track
uniform float shading; // = 0.6
// @color Color of the tray under the tiles
uniform vec4 tray; // = vec4(0.11, 0.11, 0.13, 1.0)
// @color Color of the track
uniform vec4 track; // = vec4(0.62, 0.6, 0.55, 1.0)

const float EDGE = 0.0016;

// Hilbert curve from the bottom left cell to the bottom right one; -1 and n*n are the cells just outside
vec2 cellAt(float d, float n) {
  if (d < 0.0) return vec2(-1.0, 0.0);
  if (d > n * n - 0.5) return vec2(n, 0.0);
  vec2 p = vec2(0.0);
  float t = d;
  float s = 1.0;
  for (int i = 0; i < 3; i++) {
    if (s < n) {
      float rx = mod(floor(t / 2.0), 2.0);
      float ry = abs(mod(t, 2.0) - rx);
      if (ry < 0.5) {
        if (rx > 0.5) p = s - 1.0 - p;
        p = p.yx;
      }
      p += s * vec2(rx, ry);
      t = floor(t / 4.0);
      s *= 2.0;
    }
  }
  return p;
}

float indexAt(vec2 c, float n) {
  float d = 0.0;
  vec2 p = c;
  float s = n / 2.0;
  for (int i = 0; i < 3; i++) {
    if (s >= 1.0) {
      float rx = mod(floor(p.x / s), 2.0);
      float ry = mod(floor(p.y / s), 2.0);
      d += s * s * (rx > 0.5 ? 3.0 - ry : ry);
      if (ry < 0.5) {
        if (rx > 0.5) p = n - 1.0 - p;
        p = p.yx;
      }
      s /= 2.0;
    }
  }
  return d;
}

float turns(vec2 a, vec2 c, vec2 b) {
  a -= c;
  b -= c;
  return abs(a.x * b.y - a.y * b.x);
}

float sdBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - abs(v));
}

vec4 transition(vec2 uv) {
  float n = floor(exp2(clamp(float(order), 1.0, 3.0)) + 0.5);
  float N = n * n;
  vec2 asp = vec2(ratio, 1.0);
  float open = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
  float q = clamp((progress - 0.07) / 0.86, 0.0, 1.0);
  float D = N * mix(q, q * q * (3.0 - 2.0 * q), 0.7);
  float K = floor(D);
  float f = D - K;
  // slower at the cells so that the grid reads, never stopping
  f -= 0.5 * sin(6.2831853 * f) / 6.2831853;

  vec2 g = uv * n;
  vec2 cell = clamp(floor(g), 0.0, n - 1.0);
  float dc = indexAt(cell, n);
  float px = EDGE * n;
  float hs = 0.5 - 0.5 * clamp(gap, 0.05, 0.4) * open;
  float radius = 0.1 * open;

  vec2 gs = g * asp;
  float tw = 0.1 * min(ratio, 1.0);
  vec2 cc = (cell + 0.5) * asp;
  float dl = min(sdSegment(gs, cc, (cellAt(dc - 1.0, n) + 0.5) * asp),
                 sdSegment(gs, cc, (cellAt(dc + 1.0, n) + 0.5) * asp));
  vec4 col = mix(tray, track, (1.0 - smoothstep(tw - px, tw + px, dl)) * (0.65 + 0.35 * smoothstep(0.0, 0.35 * tw, dl)));

  float shadow = 0.0;
  vec4 acc = vec4(0.0);
  float alpha = 0.0;
  for (int i = 0; i < 9; i++) {
    vec2 nc = cell + vec2(mod(float(i), 3.0), floor(float(i) / 3.0)) - 1.0;
    bool entry = nc.x == -1.0 && nc.y == 0.0;
    if (!entry && (min(nc.x, nc.y) < 0.0 || max(nc.x, nc.y) > n - 1.0)) continue;
    // one tile per path segment: the one between cell k and cell k + 1
    float k = entry ? -1.0 : indexAt(nc, n);
    float j = k - K;
    if (j < -N) continue;
    vec2 c1 = cellAt(k + 1.0, n);
    vec2 lc = g - 0.5 - mix(nc, c1, f);
    vec2 lp = lc * asp;
    // two tiles on either side of a turn are only max(f, 1 - f) apart on each axis: shrink them to pass
    float lim = mix(0.5, 0.25 + 0.5 * (sqrt((f - 0.5) * (f - 0.5) + 0.0025) - 0.05), open);
    float h = max(turns(cellAt(k - 1.0, n), nc, c1), turns(nc, c1, cellAt(k + 2.0, n))) > 0.5 ? min(hs, lim) : hs;
    // at rest the tiles in the grid overlap by a few pixels so that no seam shows, the entry tile stays outside
    vec2 hb = h * asp + 3.0 * px * (1.0 - open) * (k >= 0.0 && k < N ? 1.0 : -1.0);
    float sd = sdBox(lp, hb, radius * h);
    // fading before half a cell keeps the shadow inside the cells that search for this tile
    float fade = 1.0 - smoothstep(0.4, 0.5, max(abs(lc.x), abs(lc.y)));
    shadow = max(shadow, open * fade * (1.0 - smoothstep(-0.04, 0.12, sdBox(lp - vec2(0.04, -0.06), hb, radius * h))));
    float cover = 1.0 - smoothstep(-px, px, sd);
    if (cover <= 0.0) continue;
    vec2 src = cellAt(j >= 0.0 ? j : j + N, n);
    vec2 suv = mirror((src + 0.5 + 0.5 * lp / (h * asp)) / n);
    vec4 c = j >= 0.0 ? getFromColor(suv) : getToColor(suv);
    float rim = 1.0 - smoothstep(0.0, 0.05, -sd);
    float lit = dot(normalize(lp / hb + 1e-5), vec2(-0.7071, 0.7071));
    c.rgb *= 1.0 + shading * open * (rim * 0.35 * lit - 0.08 * (1.0 - rim));
    acc = mix(acc, c, cover);
    alpha = mix(alpha, 1.0, cover);
  }
  col.rgb *= 1.0 - 0.6 * shading * shadow;
  return mix(col, acc / max(alpha, 1e-4), alpha);
}
