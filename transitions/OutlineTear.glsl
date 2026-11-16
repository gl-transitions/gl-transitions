// Author: gre
// License: MIT
// Description: The outgoing image tears across along its own strongest outline, such as a horizon, showing white paper fibers; the torn top is pulled up and the bottom drops down, casting soft shadows on the incoming image
// Tags: tear, paper, split, vertical, content, shadow

// @range(0, 0.05) Width of the white torn edge, relative to the image height
uniform float rim; // = 0.012
// @range(0, 0.06) How ragged the tear is around the outline, relative to the image height
uniform float roughness; // = 0.025
// @color Color of the paper fibers on the torn edges
uniform vec4 paper; // = vec4(1.0, 0.98, 0.94, 1.0)
// @color Color of the shadow cast on the incoming image
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.4)

const float SPACING = 0.2;
const float LO = 0.15;
const float HI = 0.85;

float luma(vec2 p) {
  return dot(getFromColor(p).rgb, vec3(0.299, 0.587, 0.114));
}

// height of the strongest vertical brightness change in the column at knot i, sampled on a coarse ladder
float knot(float i) {
  float x = clamp(i * SPACING / ratio, 0.0, 1.0);
  float prev = luma(vec2(x, LO));
  // the tiny prior falls back to the middle on flat columns; d is scaled so it survives half precision
  float sw = 1e-4, sy = 0.5e-4;
  for (int j = 1; j < 9; j++) {
    float y = mix(LO, HI, float(j) / 8.0);
    float cur = luma(vec2(x, y));
    float m = y - 0.5 * (HI - LO) / 8.0;
    float d = 4.0 * abs(cur - prev) * (1.0 - 1.2 * abs(m - 0.5));
    float w = d * d * d * d;
    sw += w;
    sy += w * m;
    prev = cur;
  }
  return sy / sw;
}

float tri(float x) {
  return abs(fract(x) - 0.5) - 0.25;
}

// quadratic B-spline through the knots keeps the path smooth whatever the texture
float outline(float x) {
  float u = x * ratio / SPACING;
  float i = floor(u + 0.5);
  float f = u - i + 0.5;
  float a = knot(i - 1.0), b = knot(i), c = knot(i + 1.0);
  return 0.5 * (1.0 - f) * (1.0 - f) * a + (0.5 + f - f * f) * b + 0.5 * f * f * c;
}

float jag(float x) {
  return roughness * (0.2 * sin(x * 13.0 + 1.1) + 0.5 * tri(x * 23.0 + sin(x * 7.0)) + 0.25 * tri(x * 61.0 + 0.6 * sin(x * 17.0)));
}

float fibers(float x, float seed) {
  return rim * (0.7 + 0.3 * sin(x * 41.0 + seed) + 0.4 * tri(x * 89.0 + seed));
}

vec4 torn(vec4 bg, vec4 col, float e, float limit, float aa, float fiber) {
  vec4 c = vec4(mix(col.rgb, paper.rgb, clamp(0.5 + e / aa, 0.0, 1.0) * paper.a * fiber), col.a);
  return mix(bg, c, clamp(0.5 - (e - limit) / aa, 0.0, 1.0));
}

vec4 transition(vec2 uv) {
  float p = progress;
  float xr = uv.x * ratio;
  float y0 = outline(uv.x);
  float edge = y0 + jag(xr);
  // the outline stays within [LO, HI], so this carries both halves out of the frame
  float reach = HI + 0.5 * roughness + 2.0 * rim + 0.02;
  // the top peels from the left, the bottom from the right
  float move = reach * p * p * (0.2 + 0.8 * p);
  float up = move * (1.0 + 0.12 * (1.0 - uv.x) * (1.0 - p));
  float down = move * (1.0 + 0.12 * uv.x * (1.0 - p));
  float fiber = smoothstep(0.0, 0.15, p);
  float aa = 0.0015;

  float ty = uv.y - up;
  float by = uv.y + down;
  vec4 to = getToColor(uv);
  float d = min(0.7 * (y0 - ty), 1.5 * (by - y0));
  float sh = shadow.a * fiber * (1.0 - smoothstep(0.7, 1.0, p)) * (1.0 - smoothstep(-0.02, 0.07, d));
  vec4 c = vec4(mix(to.rgb, shadow.rgb, sh), to.a);
  // the bottom half reaches under the top one so their seam is invisible at the start
  c = torn(c, getFromColor(vec2(uv.x, min(by, 1.0))), by - edge, fibers(xr, 2.0) * 1.4 * fiber + 0.003, aa, fiber);
  c = torn(c, getFromColor(vec2(uv.x, max(ty, 0.0))), edge - ty, fibers(xr, 0.0) * fiber, aa, fiber);
  return c;
}
