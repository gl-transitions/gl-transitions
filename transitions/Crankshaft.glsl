// Author: gre
// License: MIT
// Description: The picture is cut into upright slats hung on the throws of one crankshaft: as it turns, each slat circles up and back while the slat of the incoming picture on the opposite throw circles down and forward into its place, the turn rolling across the frame from left to right
// Tags: mechanical, 3d, stripes, crank

// @range(3, 16) Number of slats across a 16:9 frame, fewer in narrower frames
uniform float slats; // = 6.0
// @range(0.1, 1) How far the slats swing back, as a fraction of the frame height
uniform float depth; // = 0.5

const float PI = 3.14159265;
// slats are a bit taller than the frame so that its border is never antialiased;
// a throw of half their height lets the two slats of a column pass without overlapping
const float MARGIN = 0.01;
const float THROW = 0.5 + MARGIN;
// slats overlap their neighbours, so that receding ones leave narrower gaps
const float OVER = 0.12;
const float PERSP = 0.6;
const float AA = 0.003;
// layers closer than this in depth blend, so overlapping slats never swap in a single frame
const float TIE = 0.01;

float slatCount() {
  return clamp(floor(slats * sqrt(ratio * 0.5625) + 0.5), 2.0, 16.0);
}

float crankAngle(float i, float n) {
  float c = clamp(progress * 1.6 - 0.6 * i / (n - 1.0), 0.0, 1.0);
  return PI * c * c * (3.0 - 2.0 * c);
}

float depthOf(float a) {
  return max(depth, 0.05) * (1.0 - cos(a));
}

// (signed distance to the slat's outline on screen, depth, x on the slat plane, y on the slat plane)
vec4 slatAt(vec2 P, float fi, float k, float n, float w) {
  float a = crankAngle(fi, n) + PI * k;
  float z = depthOf(a);
  float s = 1.0 / (1.0 + PERSP * z);
  vec2 Q = P / s - vec2(0.0, THROW * sin(a));
  vec2 d = abs(Q - vec2((fi + 0.5) * w - 0.5 * ratio, 0.0)) - vec2((0.5 + OVER) * w, 0.5 + MARGIN);
  return vec4(max(d.x, d.y) * s, z, Q);
}

float shadowAt(vec2 P, float zr, float n, float w) {
  float sh = 0.0;
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    if (fi >= n) break;
    for (int k = 0; k < 2; k++) {
      float gap = zr - depthOf(crankAngle(fi, n) + PI * float(k));
      if (gap < 1e-3) continue;
      vec4 c = slatAt(P - vec2(0.04, -0.07) * gap, fi, float(k), n, w);
      sh = max(sh, (1.0 - smoothstep(-0.01, 0.02 + 0.08 * gap, c.x)) * min(gap / max(depth, 0.05), 1.0));
    }
  }
  return sh;
}

vec4 transition(vec2 uv) {
  vec2 P = (uv - 0.5) * vec2(ratio, 1.0);
  float n = slatCount();
  float w = ratio / n;
  vec4 c1 = vec4(0.0), c2 = vec4(0.0);
  float z1 = 1e3, z2 = 1e3, a1 = 0.0, a2 = 0.0;
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    if (fi >= n) break;
    for (int k = 0; k < 2; k++) {
      vec4 sl = slatAt(P, fi, float(k), n, w);
      float cov = clamp(0.5 - sl.x / AA, 0.0, 1.0);
      if (cov <= 0.0) continue;
      float z = sl.y;
      vec2 q = 1.0 - abs(1.0 - abs(sl.zw / vec2(ratio, 1.0) + 0.5));
      vec4 col = k == 0 ? getFromColor(q) : getToColor(q);
      col.rgb *= 1.0 - 0.45 * z / (2.0 * max(depth, 0.05)) - 0.25 * (1.0 - smoothstep(0.0, 0.01, -sl.x)) * sin(crankAngle(fi, n));
      // neighbours at the same depth share a seam: their coverages add up to one
      float dz = z - z1;
      if (abs(dz) < TIE) {
        float m = abs(dz) / TIE;
        vec4 front = dz < 0.0 ? mix(c1, col, cov) : mix(col, c1, a1);
        c1 = mix(mix(c1, col, cov / max(a1 + cov, 1e-4)), front, m);
        a1 = mix(min(a1 + cov, 1.0), a1 + cov - a1 * cov, m);
        z1 = min(z1, z);
      }
      else if (z < z1) { z2 = z1; c2 = c1; a2 = a1; z1 = z; c1 = col; a1 = cov; }
      else if (abs(z - z2) < 1e-4) { c2 = mix(c2, col, cov / max(a2 + cov, 1e-4)); a2 = min(a2 + cov, 1.0); }
      else if (z < z2) { z2 = z; c2 = col; a2 = cov; }
    }
  }
  vec4 bg = getToColor(uv);
  bg.rgb *= 0.3;
  if (a2 > 0.0 && a1 < 1.0) c2.rgb *= 1.0 - 0.6 * shadowAt(P, z2, n, w);
  if (a1 > 0.0) c1.rgb *= 1.0 - 0.6 * shadowAt(P, z1, n, w);
  return mix(mix(bg, c2, a2), c1, a1);
}
