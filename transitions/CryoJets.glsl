// Author: gre
// License: MIT
// Description: Nozzles along the bottom of the frame fire tall white jets of cold fog in a quick chase from the middle out to the sides; the plumes billow and merge, then lift off their nozzles and break up as they drift away, leaving the incoming picture behind
// Tags: fog, smoke, stage, organic, reveal

// @range(2.0, 9.0, 1.0) Number of jets across a 16:9 frame (fewer in portrait)
uniform float jets; // = 5.0
// @range(0.0, 1.0) Delay of the chase from the middle jets out to the side ones
uniform float chase; // = 0.5
// @color Color of the lit fog
uniform vec4 fogColor; // = vec4(0.97, 0.98, 1.0, 1.0)
// @color Color of the fog in its folds
uniform vec4 shadeColor; // = vec4(0.72, 0.8, 0.92, 1.0)

float cjHash(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float cjHash2(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float cjNoise(vec2 v) {
  vec2 i = floor(v);
  vec2 f = fract(v);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(cjHash2(i), cjHash2(i + vec2(1.0, 0.0)), f.x),
    mix(cjHash2(i + vec2(0.0, 1.0)), cjHash2(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

float cjFbm(vec2 v) {
  float s = 0.0;
  float w = 0.5;
  for (int i = 0; i < 4; i++) {
    s += w * cjNoise(v);
    v = mat2(1.6, 1.2, -1.2, 1.6) * v + 5.3;
    w *= 0.5;
  }
  return s / 0.9375;
}

// capped below one spacing so that only the three nearest jets can reach a pixel
float cjGrow(float a, float y, float sp) {
  return sp * (1.0 - exp(-(0.08 + a + 30.0 * a * a) - y * (0.2 + 0.6 * a) / sp));
}

float cjTop(float a) {
  return 1.7 * (1.0 - exp(-a * 9.0));
}

vec4 transition(vec2 uv) {
  float p = progress;
  float n = max(2.0, floor(jets * sqrt(ratio / 1.778) + 0.5));
  float sp = ratio / n;
  vec2 P = vec2(uv.x * ratio, uv.y);
  float k0 = floor(P.x / sp);
  float minOff = 0.5 - 0.5 * mod(n, 2.0);
  float span = 0.06 + 0.22 * chase;
  float fog = 0.0;
  float lit = 0.0;
  float wsum = 0.0;
  float rev = 0.0;
  for (int j = -1; j <= 1; j++) {
    float k = k0 + float(j);
    float valid = step(0.0, k) * step(k, n - 1.0);
    float dx = P.x - (k + 0.5) * sp;
    float order = (abs(k + 0.5 - 0.5 * n) - minOff) / max(0.5 * n - 0.5 - minOff, 0.5);
    float t0 = span * order * (0.85 + 0.15 * cjHash(k + 7.0));
    float a = max(p - t0, 0.0);
    float an = a / (1.0 - t0);
    // once the valve shuts, the whole cloud drifts up off its nozzle and out of the frame
    float x = max(an - 0.12, 0.0) / 0.88;
    float rise = 1.05 * x * (0.6 + 0.4 * x);
    float yc = P.y - rise;
    float top = cjTop(a);
    float grow = cjGrow(a, max(yc, 0.0), sp);
    // self-similar billows: their size follows the plume's width as they rise
    float c0 = 0.1 + 0.4 * sp;
    float h = log(1.0 + max(yc, 0.0) / c0) + min(yc, 0.0) / c0;
    vec2 q = vec2(dx / grow * 1.6 + cjHash(k) * 9.0, h * 3.4 - a * 9.0 + k * 3.7);
    float b = cjFbm(q);
    float y = yc + (b - 0.5) * 0.3 * top;
    float m = (1.0 - smoothstep(0.6, 1.05, abs(dx) / grow + (b - 0.5) * 1.4)) * (1.0 - smoothstep(top - 0.25, top, y));
    m *= (1.0 - smoothstep(1.2, 1.45, abs(dx) / sp)) * smoothstep(-0.15, 0.0, yc + (b - 0.5) * 0.5 * min(rise * 4.0, 1.0));
    // every jet clears exactly at the end, the early ones more slowly
    float erode = -0.4 + 0.7 * an * (sqrt(an) + an * an);
    float d = smoothstep(erode, erode + 0.28, m * smoothstep(0.15, 0.85, b)) * smoothstep(0.0, 0.2, m) * valid;
    fog = 1.0 - (1.0 - fog) * (1.0 - d);
    lit += d * b;
    wsum += d;
    // the reveal stops growing before this jet's fog thins, so its edge never shows
    float aR = min(a, 0.3);
    float topR = cjTop(aR) - 0.45;
    float r = (1.0 - smoothstep(0.6, 0.7, abs(dx) / cjGrow(aR, P.y, sp))) * (1.0 - smoothstep(topR - 0.1, topR, P.y));
    rev = max(rev, r * valid);
  }
  // hidden under the fog; makes the end exactly the incoming picture
  rev = max(rev, smoothstep(0.6, 0.85, p));
  vec4 base = mix(getFromColor(uv), getToColor(uv), rev);
  vec4 c = mix(shadeColor, fogColor, smoothstep(0.35, 0.7, lit / max(wsum, 1e-3)) * (0.75 + 0.25 * uv.y));
  return mix(base, c, fog);
}
