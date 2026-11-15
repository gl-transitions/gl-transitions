// Author: gre
// License: MIT
// Description: The incoming image is painted over the outgoing one in layers of brush strokes, broad flat strokes of its colors first, then smaller and smaller ones, until the last fine strokes lay down its full detail
// Tags: paint, brush, artistic, dissolve, texture

// @range(0.12, 0.5) Length of the broadest brush strokes, in frame heights
uniform float brushSize; // = 0.3
// @range(-90, 90) Main direction of the brush strokes, in degrees
uniform float angle; // = 25.0
// @range(0, 1) How much the direction of the strokes changes from one layer to the next
uniform float crossing; // = 0.5
// @range(0, 1) How thick the paint looks: relief and shine of the brush marks while it is wet
uniform float impasto; // = 0.6

const float PI = 3.141592653589793;
// a stroke is about 2.5 times longer than wide: its cell is that much longer than high
const float ROW = 0.4;

float pdHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec4 pdHash4(vec2 p) {
  vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float pdNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(pdHash(i), pdHash(i + vec2(1.0, 0.0)), f.x),
    mix(pdHash(i + vec2(0.0, 1.0)), pdHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

vec2 pdFold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

// Strokes lie in rows along the direction of their layer, each row shifted by its own amount.
// A pixel looks for strokes in the 2 nearest cells of the 2 nearest rows: a stroke never reaches
// further than 1 cell along its row (0.76 + 0.06 at its dry end + 0.06 of antialiasing + 0.02 of tilt
// + 0.08 of jitter = 0.98) nor than 1 row across (0.2 + 0.06 of antialiasing + 0.05 of tilt + 0.04 of bend
// + 0.02 of jitter = 0.37, out of ROW = 0.4).
// Antialiasing is 0.0025 frame heights, which fits in 0.06 cells when cells are at least MIN_SIZE long.
const float MIN_SIZE = 0.042;

// center of the stroke of a cell (row in y) whose row is shifted by `shift`, in cells of its layer
vec2 pdCenter(vec2 cell, float shift, vec4 h) {
  return vec2(cell.x + 0.5 + shift + (h.x - 0.5) * 0.16, cell.y + 0.5 + (h.y - 0.5) * 0.1);
}

vec2 pdToUv(vec2 p, vec2 off, float size, vec2 dir) {
  vec2 l = (p - off) * vec2(size, size * ROW);
  vec2 q = dir * l.x + vec2(-dir.y, dir.x) * l.y;
  return q / vec2(ratio, 1.0) + 0.5;
}

// the stroke centered at c (in cells of layer k, offset by `off`) seen from p.
// returns (coverage, relief shading, start time, streaks)
vec4 pdStroke(vec2 p, vec2 c, vec2 cell, vec4 h, float size, float k, vec2 off, float t0, float spread, float dur, float dry, vec2 dir) {
  vec2 d = (p - c) * vec2(1.0, ROW); // in stroke lengths
  float tilt = (h.z - 0.5) * 0.12;
  float a = d.x + tilt * d.y; // along the stroke
  float b = d.y - tilt * d.x - (h.w - 0.5) * 0.12 * a * a; // across it
  float L = 0.66 + 0.1 * h.w;
  float W = 0.17 + 0.03 * h.z;
  vec2 world = (c - off) * vec2(size, size * ROW);
  float order = 0.55 * pdNoise(world * 3.0 + k * 5.0) + 0.45 * pdHash(cell * 1.7 + vec2(k * 9.0, 3.0));
  float start = t0 + spread * clamp((order - 0.15) / 0.7, 0.0, 1.0); // (order is mostly in 0.15..0.85)
  float s = clamp((progress - start) / dur, 0.0, 1.0);
  s = 1.0 - (1.0 - s) * (1.0 - s);
  float seed = h.x * 37.0 + k * 11.0;
  float bw = b / W; // -1..1 across the core of the stroke
  // bristle streaks along the stroke (fewer on small strokes, so that they stay a few pixels wide)
  float hairs = clamp(size * 50.0, 3.0, 16.0);
  float br = 0.6 * pdNoise(vec2(bw * 0.4 * hairs + seed, a * 2.0)) + 0.4 * pdNoise(vec2(bw * 0.8 * hairs - seed, a * 1.2 + 5.0));
  float aa = 0.0025 / size;
  float u = clamp(a / L, -1.0, 1.0);
  float width = (0.8 + 0.2 * (1.0 - u * u)) * (0.92 + 0.08 * pdNoise(vec2(a * 6.0, seed))) - 0.1 * br;
  float side = 1.0 - smoothstep(width - aa / W, width + aa / W, abs(bw));
  float tail = smoothstep(-aa, aa, a + L - 0.12 * bw * bw);
  float head = mix(-L - 0.1, L + 0.2, s);
  float lay = smoothstep(0.0, 0.25, (head - a) / 0.2 - 0.6 * br);
  float lift = smoothstep(-aa, aa, L + 0.12 * (br - 0.5) - a);
  float fb = pdNoise(vec2(bw * hairs + seed, a * 0.9 - seed));
  float dryness = dry * smoothstep(0.1, 1.0, u);
  float cover = side * tail * lay * lift * (1.0 - dryness * (1.0 - smoothstep(0.3, 0.6, fb)));
  float ridge = bw * (1.0 - 0.5 * abs(bw)) * 0.8 + (br - 0.5) + 0.7 * (fb - 0.5);
  float facing = dot(vec2(-dir.y, dir.x), vec2(-0.6, 0.8));
  return vec4(cover, -ridge * facing, start, br);
}

// how much stroke x shows through stroke y: hidden by y where y was laid down after it
float pdUnder(vec4 x, vec4 y) {
  return y.z > x.z ? 1.0 - y.x : 1.0;
}

// paints one layer of strokes over `below`, at an angle `th`.
// solid layers take the color of the incoming image under the middle of each stroke, the detail
// layers lay down the incoming image itself (`detail`, at this pixel), with less dry gaps
vec4 pdLayer(vec4 below, vec2 q, float size, float k, float th, float t0, float spread, float dur, bool solid, vec4 detail) {
  size = max(size, MIN_SIZE);
  vec2 dir = vec2(cos(th), sin(th));
  vec2 off = vec2(k * 0.37, k * 0.61);
  vec2 p = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) / vec2(size, size * ROW) + off;
  float r = floor(p.y - 0.5);
  float sh0 = pdHash(vec2(r, 7.3));
  float sh1 = pdHash(vec2(r + 1.0, 7.3));
  float x0 = floor(p.x - sh0 - 0.5);
  float x1 = floor(p.x - sh1 - 0.5);
  vec2 c0 = vec2(x0, r);
  vec2 c1 = vec2(x0 + 1.0, r);
  vec2 c2 = vec2(x1, r + 1.0);
  vec2 c3 = vec2(x1 + 1.0, r + 1.0);
  vec2 kk = vec2(k * 41.0, k * 17.0);
  vec4 h0 = pdHash4(c0 + kk);
  vec4 h1 = pdHash4(c1 + kk);
  vec4 h2 = pdHash4(c2 + kk);
  vec4 h3 = pdHash4(c3 + kk);
  vec2 m0 = pdCenter(c0, sh0, h0);
  vec2 m1 = pdCenter(c1, sh0, h1);
  vec2 m2 = pdCenter(c2, sh1, h2);
  vec2 m3 = pdCenter(c3, sh1, h3);
  float dry = solid ? 0.85 : 0.4;
  vec4 s0 = pdStroke(p, m0, c0, h0, size, k, off, t0, spread, dur, dry, dir);
  vec4 s1 = pdStroke(p, m1, c1, h1, size, k, off, t0, spread, dur, dry, dir);
  vec4 s2 = pdStroke(p, m2, c2, h2, size, k, off, t0, spread, dur, dry, dir);
  vec4 s3 = pdStroke(p, m3, c3, h3, size, k, off, t0, spread, dur, dry, dir);
  float v0 = s0.x * pdUnder(s0, s1) * pdUnder(s0, s2) * pdUnder(s0, s3);
  float v1 = s1.x * pdUnder(s1, s0) * pdUnder(s1, s2) * pdUnder(s1, s3);
  float v2 = s2.x * pdUnder(s2, s0) * pdUnder(s2, s1) * pdUnder(s2, s3);
  float v3 = s3.x * pdUnder(s3, s0) * pdUnder(s3, s1) * pdUnder(s3, s2);
  vec4 k0 = detail;
  vec4 k1 = detail;
  vec4 k2 = detail;
  vec4 k3 = detail;
  // only the strokes that show are sampled
  if (solid) {
    if (v0 > 0.0) k0 = getToColor(pdFold(pdToUv(m0, off, size, dir)));
    if (v1 > 0.0) k1 = getToColor(pdFold(pdToUv(m1, off, size, dir)));
    if (v2 > 0.0) k2 = getToColor(pdFold(pdToUv(m2, off, size, dir)));
    if (v3 > 0.0) k3 = getToColor(pdFold(pdToUv(m3, off, size, dir)));
  }
  float relief = impasto * (solid ? 0.18 : 0.12) * (1.0 - smoothstep(0.7, 0.95, progress));
  k0.rgb *= 1.0 + relief * (s0.y + 0.5 * (s0.w - 0.5));
  k1.rgb *= 1.0 + relief * (s1.y + 0.5 * (s1.w - 0.5));
  k2.rgb *= 1.0 + relief * (s2.y + 0.5 * (s2.w - 0.5));
  k3.rgb *= 1.0 + relief * (s3.y + 0.5 * (s3.w - 0.5));
  float vis = v0 + v1 + v2 + v3;
  return below * (1.0 - vis) + k0 * v0 + k1 * v1 + k2 * v2 + k3 * v3;
}

vec4 transition(vec2 uv) {
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  vec4 to = getToColor(uv);
  vec4 col = getFromColor(uv);
  float sz = brushSize;
  float th = angle * PI / 180.0;
  float x = crossing * 0.6;
  col = pdLayer(col, q, sz, 0.0, th, 0.0, 0.3, 0.12, true, to);
  col = pdLayer(col, q, sz * 0.6, 1.0, th + x, 0.2, 0.28, 0.1, true, to);
  col = pdLayer(col, q, sz * 0.36, 2.0, th - x * 0.7, 0.38, 0.26, 0.09, true, to);
  col = pdLayer(col, q, sz * 0.22, 3.0, th + x * 0.4, 0.56, 0.22, 0.08, false, to);
  col = pdLayer(col, q, sz * 0.2, 4.0, th - x * 0.3, 0.68, 0.2, 0.08, false, to);
  col = mix(col, to, smoothstep(0.92, 1.0, progress));
  return clamp(col, 0.0, 1.0);
}
