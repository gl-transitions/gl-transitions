// Author: gre
// License: MIT
// Description: Warm breath fogs the cold glass in front of the picture: an uneven milky haze blooms out from the middle, water beads swell in it and act as tiny lenses holding sharp upside-down views, a few grow heavy and run down leaving clear trails, then the fog evaporates from the edges inward, the beads last, off the incoming picture
// Tags: glass, fog, water, droplets, breath, organic, dissolve

// @range(4, 20) Number of large beads across the frame height
uniform float droplets; // = 8.0
// @range(0, 1) Whiteness of the fog at its thickest
uniform float milk; // = 0.7

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

float fbm(vec2 p) {
  return 0.5 * noise(p) + 0.3 * noise(p * 2.1 + 3.7) + 0.2 * noise(p * 4.3 - 1.9);
}

// premultiplied, mirrored past the frame (min keeps uv exact inside it)
vec4 scene(vec2 uv, float m) {
  uv = mod(uv, 2.0);
  uv = min(uv, 2.0 - uv);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  return mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
}

float front() {
  float e = clamp(progress / 0.3, 0.0, 1.0);
  return mix(-0.4, 1.6, 1.0 - (1.0 - e) * (1.0 - e));
}

// breath distance of a bead centre, without the costly noise: radial plus per-bead jitter
float reach(vec2 q, float jitter) {
  return length((q - vec2(0.06, -0.04)) * vec2(0.85, 1.0)) / (0.5 * length(vec2(ratio, 1.0))) + 0.35 * (jitter - 0.5);
}

// beads condense behind the fog front and evaporate from the edges inward, area shrinking steadily
float beadSize(float rr, float lag) {
  float end = 0.8 + 0.2 * clamp(1.0 - rr, 0.0, 1.0);
  return smoothstep(0.0, 0.3, front() - lag - rr) * sqrt(clamp((end - progress) / 0.3, 0.0, 1.0));
}

// spherical cap: x = height in cell units, yz = surface slope, w = height change per frame height
vec4 bead(vec2 g, vec2 ctr, float r, float cell) {
  float rs = max(r, 1e-3);
  vec2 d = (g - ctr) * vec2(1.0, 1.08);
  float w = max(1.0 - dot(d, d) / (rs * rs), 0.0);
  float sw = sqrt(w);
  vec2 slope = -d * sw / (rs * (w + 0.01)) * min(r * 1000.0, 1.0);
  // -1 off the bead keeps the smooth max from inflating empty glass
  return vec4(w > 0.0 ? r * sw : -1.0, slope, length(slope) / cell);
}

// polynomial smooth max, so touching beads merge with a neck instead of stacking
vec4 merge(vec4 a, vec4 b) {
  float k = 0.03;
  float h = clamp(0.5 + 0.5 * (b.x - a.x) / k, 0.0, 1.0);
  vec4 c = mix(a, b, h);
  c.x += k * h * (1.0 - h);
  return c;
}

vec4 beads(vec4 acc, vec2 q, float cell, float fill, float lag, float grow, float salt) {
  vec2 g = q / cell;
  vec2 base = floor(g);
  for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
      vec2 c = base + vec2(float(i), float(j)) + salt;
      float h = hash(c);
      vec2 ctr = c - salt + 0.2 + 0.6 * vec2(hash(c + 17.0), hash(c + 31.0));
      float size = beadSize(reach(ctr * cell, hash(c + 71.0)), lag) * grow;
      float r = (0.16 + 0.34 * h * h) * size * step(1.0 - fill, hash(c + 53.0));
      acc = merge(acc, bead(g, ctr, r, cell));
    }
  return acc;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float n = fbm(q * 3.0 + 2.0);
  // distance from the breath's middle, ragged by noise, ~1 at the corners
  float rr = length((q - vec2(0.06, -0.04)) * vec2(0.85, 1.0)) / (0.5 * length(vec2(ratio, 1.0))) + 0.35 * (n - 0.5);
  float fr = front();
  float back = 1.6 - 2.7 * clamp((p - 0.42) / 0.58, 0.0, 1.0);
  float fog = smoothstep(0.0, 0.3, fr - rr) * smoothstep(0.0, 0.3, back - rr);
  float m = smoothstep(0.34, 0.5, p);

  float cell = 1.0 / droplets;
  float grow = smoothstep(0.08, 0.45, p);
  vec4 water = beads(vec4(-1.0, 0.0, 0.0, 0.0), q, cell, 0.6, 0.2, grow, 0.0);
  water = beads(water, q, cell * 0.4, 0.5, 0.05, 1.0, 71.0);

  float cw = 2.3 * cell;
  float col = floor(q.x / cw);
  float hk = hash(vec2(col, 7.0));
  float t0 = 0.24 + 0.16 * hash(vec2(col, 13.0));
  float slide = smoothstep(t0, t0 + 0.55, p);
  float y0 = 0.45 - 0.6 * hash(vec2(col, 29.0));
  float yr = y0 - 1.4 * slide;
  float xr = (col + 0.5) * cw + 0.25 * cell * sin(q.y * 9.0 + hk * 6.0);
  float xh = (col + 0.5) * cw + 0.25 * cell * sin(yr * 9.0 + hk * 6.0);
  float rRun = 0.36 * grow * beadSize(reach(vec2(xh, yr), hk), 0.2) * step(0.35, hk);
  float trail = (1.0 - smoothstep(0.15, 0.3, abs(q.x - xr) / cell)) * step(yr, q.y) * (1.0 - smoothstep(y0 - 0.02, y0 + 0.02, q.y)) * smoothstep(0.0, 0.1, rRun);
  // the runner sweeps up every droplet in its path
  water = merge(mix(water, vec4(-1.0, 0.0, 0.0, 0.0), trail), bead(q / cell, vec2(xh, yr) / cell, rRun, cell));
  float dens = fog * (0.6 + 0.9 * fbm(q * 2.2 + 9.0)) * (0.8 + 0.4 * fbm(q * 8.0 - 4.0)) * (1.0 - trail);
  // beads absorb the mist around them
  dens *= 1.0 - 0.5 * smoothstep(0.0, 0.05, water.x);
  dens = clamp(dens, 0.0, 1.0);

  float rad = 0.035 * dens;
  vec4 c = vec4(0.0);
  for (int k = 0; k < 12; k++) {
    float fk = float(k);
    float a = fk * 2.39996;
    c += scene(uv + rad * sqrt((fk + 0.5) / 12.0) * vec2(cos(a) / ratio, sin(a)), m);
  }
  c /= 12.0;
  vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  vec3 haze = mix(vec3(dot(rgb, vec3(0.299, 0.587, 0.114))), vec3(1.0), 0.65) * vec3(0.95, 0.97, 1.0);
  rgb = mix(rgb, haze, clamp(milk * dens, 0.0, 1.0));

  float T = 0.03;
  // AA capped below T so vanishing beads (r -> 0, steep slopes) fade out completely
  float aa = clamp(water.w * 0.0015, 1e-4, 0.4 * T);
  float inside = smoothstep(-aa, aa, water.x - T);
  // a bead is a plano-convex lens: it shows an inverted, shrunken view of the scene behind it
  vec2 slope = water.yz * 1.3;
  vec3 nrm = normalize(vec3(-slope, 1.0));
  vec4 lc = scene(uv - nrm.xy * vec2(0.35 / ratio, 0.35), m);
  vec3 drop = lc.a > 0.0 ? lc.rgb / lc.a : vec3(0.0);
  float steep = 1.0 - nrm.z;
  vec3 L = normalize(vec3(-0.45, 0.6, 0.66));
  float spec = pow(max(dot(nrm, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), 80.0);
  float caustic = smoothstep(0.1, 0.4, steep) * max(dot(slope, -L.xy), 0.0) / max(length(slope), 1e-3);
  drop = drop * (1.0 - 0.8 * smoothstep(0.45, 0.8, steep)) + 0.3 * caustic * (1.0 - smoothstep(0.5, 0.75, steep));
  drop += 0.9 * spec + 0.12 * smoothstep(0.75, 0.9, steep);
  rgb *= 1.0 - 0.25 * smoothstep(0.5 * T, T, water.x) * (1.0 - inside);

  float aOut = mix(c.a, lc.a, inside);
  return vec4(mix(rgb, drop, inside), aOut);
}
