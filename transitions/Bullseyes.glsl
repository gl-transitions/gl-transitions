// Author: gre
// License: MIT
// Description: The outgoing image turns into a patchwork of small and large squares where concentric circles, squares and diamonds in flat colors of both images keep pulsing outwards, one inside another, from the middle of the frame to its corners; the last pulse of each square opens onto the incoming image
// Tags: geometric, rings, squares, grid, pattern, colorful

// @range(2, 8, 1) Number of large squares along the shorter side of the frame
uniform float count; // = 4.0
// @range(0, 1) Share of the large squares that are split into four small ones
uniform float split; // = 0.45
// @range(0, 1) How far the pulses lag from the middle of the frame to its corners
uniform float spread; // = 0.5

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// 1 in the corners of the cell, whatever the shape
float metric(vec2 q, float kind) {
  q = abs(q);
  if (kind < 0.45) return length(q) / 1.4143;
  if (kind < 0.75) return max(q.x, q.y);
  return 0.5 * (q.x + q.y);
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// averaged over a small patch, so a ring does not flicker with the grain of a video
vec4 flatColor(vec2 c, vec2 e, bool incoming) {
  vec4 s = vec4(0.0);
  for (int i = 0; i < 4; i++) {
    vec2 st = c + e * vec2(i < 2 ? -1.0 : 1.0, i == 1 || i == 3 ? 1.0 : -1.0);
    s += 0.25 * premultiplied(incoming ? getToColor(st) : getFromColor(st));
  }
  return s;
}

vec4 transition(vec2 uv) {
  float n = max(floor(count + 0.5), 1.0);
  vec2 res = floor(n * vec2(max(ratio, 1.0), max(1.0 / ratio, 1.0)) + 0.5);
  vec2 g = uv * res;
  vec2 cell = floor(g);
  float salt = 1.0;
  if (hash12(cell + 3.0) < split) {
    salt = 2.0;
    res *= 2.0;
    g = uv * res;
    cell = floor(g);
  }
  float seed = hash12(cell + 7.0 * salt);
  float kind = hash12(cell + 31.0 * salt);
  vec2 q = 2.0 * (g - cell) - 1.0;
  vec2 c = (cell + 0.5) / res;
  vec2 asp = vec2(ratio, 1.0);
  float away = length((c - 0.5) * asp) / (0.5 * length(asp));
  float delay = 0.45 * spread * clamp(1.25 * mix(away, seed, 0.3) - 0.25, 0.0, 1.0);
  float life = 1.0 - 0.45 * spread;
  float d = metric(q, kind);
  // circles and diamonds have a gentler metric than squares
  float aa = 0.0028 * res.y * (kind < 0.45 || kind >= 0.75 ? 0.7071 : 1.0);
  vec2 off = 0.3 / res;
  vec4 col = premultiplied(getFromColor(uv));
  for (int i = 0; i < 5; i++) {
    float s = clamp(((progress - delay) / life - 0.13 * float(i)) / 0.48, 0.0, 1.0);
    s = i < 4 ? s * (1.6 - 0.6 * s) : s * (0.55 + 0.45 * s * s);
    float r = s * (1.0 + 2.0 * aa) - aa;
    float m = 1.0 - smoothstep(r - aa, r + aa, d);
    // the frame left around the last pulse fades out before it gets thin
    if (i == 4) m = max(m, smoothstep(0.7, 0.96, s));
    if (m > 0.0) {
      vec4 l;
      if (i == 4) {
        l = premultiplied(getToColor(uv));
      } else {
        vec2 o = i == 0 ? vec2(0.0) : i == 1 ? vec2(1.0) : i == 2 ? vec2(-1.0, 1.0) : vec2(-1.0);
        l = flatColor(c + off * o, 0.06 / res, i == 0 || i == 2);
      }
      col = mix(col, l, m);
    }
  }
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
