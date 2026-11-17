// Author: gre
// License: MIT
// Description: A branching discharge figure burns slowly into the outgoing picture from one point: a glowing ember front creeps out along fern-like channels, singeing the picture just ahead of it, and the burnt-through channels fill in between onto the incoming picture
// Tags: electric, lichtenberg, burn, branching, organic, fractal

// @range(0, 1) Point the figure grows from, in frame coordinates
uniform vec2 origin; // = vec2(0.5, 0.0)
// @range(3, 10, 1) Number of main channels leaving the origin
uniform int branches; // = 7

const float TAU = 6.2831853;
const float PI = 3.14159265;
// inputs wrapped small: this hash drifts between targets above a few thousand
float h11(float n) { n = fract(mod(n, 251.0) * 0.1031); n *= n + 33.33; n *= n + n; return fract(n); }
float h21(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}
float zz(float x) { float i = floor(x); return mix(h11(i), h11(i + 1.0), x - i) - 0.5; }
float vn(vec2 p) {
  vec2 i = floor(p), f = p - i;
  f *= f * (3.0 - 2.0 * f);
  return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + 1.0), f.x), f.y);
}

float target(float n, float j, float k) { return (j + 0.5 + 0.7 * (h11(j * 7.0 + k * 31.0 + 3.0) - 0.5)) / n * TAU; }
float wobble(float r, float sc, float j, float k) {
  float x = r / sc * (14.0 + 8.0 * k) + j * 13.0 + k * 50.0;
  return sc * (0.03 - 0.004 * k) * (zz(x) + 0.4 * zz(x * 3.1));
}

// each level doubles the spokes; a spoke starts on its parent's angle and veers to its own past the fork radius
float tree(float a, float r, float sc) {
  float best = 9.0, n = float(branches), rk = 0.0;
  for (int k = 0; k < 5; k++) {
    float fk = float(k);
    if (r > rk) {
      float ci = floor(a / TAU * n);
      for (int o = -1; o <= 1; o++) {
        float j = mod(ci + float(o), n);
        float tA = target(n, j, fk);
        float pA = k == 0 ? tA : target(n * 0.5, floor(j * 0.5), fk - 1.0);
        tA = pA + mod(tA - pA + PI, TAU) - PI;
        float fork = k == 0 ? 1.0 : smoothstep(rk, rk + 0.08 * sc, r);
        float sa = mix(pA, tA, fork);
        float da = mod(a - sa + PI, TAU) - PI;
        float lat = wobble(r, sc, j, fk);
        if (k > 0) lat = mix(wobble(r, sc, floor(j * 0.5), fk - 1.0), lat, fork);
        best = min(best, abs(da * r - lat) * (1.0 + 0.5 * fk));
      }
    }
    n *= 2.0;
    rk += sc * (0.08 + 0.05 * fk);
  }
  return best;
}

vec4 transition(vec2 uv) {
  float p = progress, R = ratio;
  vec2 c = vec2(origin.x * R, origin.y);
  vec2 P = vec2(uv.x * R, uv.y) - c;
  // the offset keeps atan defined on the origin's own pixel
  float r = length(P), a = atan(P.y, P.x + 1e-6) + PI;
  float reach = length(max(c, vec2(R, 1.0) - c));
  vec4 A = getFromColor(uv), B = getToColor(uv);
  float d = tree(a, r, reach);
  float luma = dot(A.rgb, vec3(0.299, 0.587, 0.114));
  // sqrt keeps channels thin behind the front (offset: finite slope, no aliasing); darker areas burn a bit sooner
  float T = 0.5 * r / reach + 0.6 * (sqrt(clamp(d / (0.12 * reach), 0.0, 0.36) + 0.03) - 0.1732) + 0.05 * luma + 0.03 * vn(P * 30.0);
  float e = T - (p * 1.04 - 0.02 + 0.05 * sin(PI * p));
  float on = smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.85, 1.0, p));
  // the hole lags the front: channels char first, then crumble open
  float lag = 0.13;
  float hole = 1.0 - smoothstep(-lag - 0.004, -lag + 0.004, e);
  float singe = (1.0 - smoothstep(0.0, 0.07, e)) * on;
  float charred = 1.0 - smoothstep(-0.01, 0.004, e);
  vec3 col = mix(A.rgb, A.rgb * vec3(0.7, 0.5, 0.32), singe * 0.6);
  col = mix(col, A.rgb * 0.12 + vec3(0.06, 0.03, 0.015), charred * 0.92);
  float front = exp(-abs(e) * 90.0) * on;
  float tip = exp(-d / reach * 45.0);
  float edge = exp(-abs(e + lag) * 90.0) * on;
  col += 1.4 * front * mix(vec3(1.0, 0.4, 0.06), vec3(1.0, 0.85, 0.55), tip);
  col += edge * vec3(0.9, 0.3, 0.04) * (0.6 + 0.4 * vn(P * 90.0 + p * 20.0));
  vec3 b = B.rgb * (1.0 - 0.5 * exp((e + lag) * 60.0) * on) + 0.5 * edge * vec3(0.9, 0.3, 0.04);
  return vec4(clamp(mix(col, b, hole), 0.0, 1.0), mix(A.a, B.a, hole));
}
