// Author: gre
// License: MIT
// Description: Lightning strikes the outgoing picture a few times: each forked bolt cracks down as a white-hot slit through which the incoming picture already shows, and the slits widen from their channels until they swallow the frame
// Tags: electric, lightning, spark, branching, reveal

// @range(1, 5, 1) Number of strikes, one after the other across the frame
uniform int strikes; // = 3
// @range(0, 1) How jagged the bolts are
uniform float jag; // = 0.6

float h11(float n) { n = fract(n * 0.1031); n *= n + 33.33; n *= n + n; return fract(n); }
// piecewise linear on purpose: the kinks are what makes a bolt read as lightning
float zz(float x) { float i = floor(x); return mix(h11(i), h11(i + 1.0), x - i) - 0.5; }
float vn(vec2 p) {
  vec2 i = floor(p), f = p - i;
  f *= f * (3.0 - 2.0 * f);
  float a = h11(i.x + i.y * 57.0), b = h11(i.x + 1.0 + i.y * 57.0);
  float c = h11(i.x + (i.y + 1.0) * 57.0), d = h11(i.x + 1.0 + (i.y + 1.0) * 57.0);
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float boltX(float y, float s, float x0, float fine) {
  float a = 0.4 + jag;
  return x0 + (h11(s * 3.7) - 0.5) * 0.35 * (1.0 - y)
    + a * (0.07 * zz(y * 5.0 + s * 11.0) + fine * (0.03 * zz(y * 16.0 + s * 7.0) + 0.01 * zz(y * 47.0 + s * 5.0)));
}

// far drops the fine kinks once the rift is wide: their offset contours would tear into teeth
float bolt(vec2 P, float s, float x0, float age, float far) {
  float yf = 1.02 - age * 22.0;
  float fine = 1.0 - far;
  float fy = boltX(P.y, s, x0, fine);
  float h = mix(0.004, 0.1, far);
  float sl = (boltX(P.y + h, s, x0, fine) - boltX(P.y - h, s, x0, fine)) / (2.0 * h);
  float d = max(abs(P.x - fy) / sqrt(1.0 + sl * sl), yf - P.y);
  for (int k = 0; k < 3; k++) {
    float fk = float(k), sk = s * 13.0 + fk;
    float yb = 0.82 - 0.24 * fk - 0.08 * h11(sk);
    float side = h11(sk * 1.7) < 0.5 ? -1.0 : 1.0;
    float th = side * (0.45 + 0.5 * h11(sk * 2.3));
    vec2 dir = vec2(sin(th), -cos(th));
    float L = (0.42 - 0.08 * fk) * (0.7 + 0.5 * h11(sk * 3.1));
    float Lg = L * clamp((yb - yf) / (L * cos(th)), 0.0, 1.0);
    vec2 q = P - vec2(boltX(yb, s, x0, fine), yb);
    float u = dot(q, dir);
    float v = dot(q, vec2(-dir.y, dir.x)) - (0.4 + jag) * (0.04 * zz(u * 12.0 + sk * 5.0) + 0.012 * zz(u * 40.0 + sk)) * clamp(u * 8.0, 0.0, 1.0);
    float db = length(vec2(max(-u, 0.0) + max(u - Lg, 0.0), v));
    // branches are thinner, so they open later than the trunk
    d = min(d, yb < yf ? 9.0 : db * 1.7 + 0.004);
  }
  return d;
}

vec4 transition(vec2 uv) {
  float p = progress, R = ratio;
  vec2 P = vec2(uv.x * R, uv.y);
  float n = clamp(float(strikes), 1.0, 5.0);
  float x = clamp((p - 0.3) / 0.7, 0.0, 1.0);
  // sized to the typical widest gap between bolts; the late term mops up seed-dependent stragglers
  float grow = x * x * (0.55 * R / n + 0.04 * R + 0.04) + 0.12 * smoothstep(0.85, 1.0, p);
  float far = smoothstep(0.0, 0.08, grow);
  float rn = vn(P * 40.0) - 0.5 + 0.5 * (vn(P * 110.0) - 0.5);
  float e = 9.0, heat = 0.0;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    if (fi < n) {
      float t0 = 0.05 + 0.3 * fi / max(n - 1.0, 1.0);
      float age = p - t0;
      if (age > 0.0) {
        float slot = floor((n - 1.0) * 0.5) + (mod(fi, 2.0) > 0.5 ? (fi + 1.0) * 0.5 : -fi * 0.5);
        float x0 = R * (slot + 0.5 + 0.5 * (h11(fi * 9.1 + 2.0) - 0.5)) / n;
        float d = bolt(P, fi + 1.0, x0, age, far);
        float w = 0.003 + 0.03 * sqrt(age);
        e = min(e, d - w * (1.0 + 0.9 * rn));
        heat += smoothstep(0.0, 0.008, age) * exp(-age * 14.0) * (0.75 + 0.5 * zz(age * 300.0 + fi * 7.0)) * exp(-max(d - w, 0.0) * 40.0);
      }
    }
  }
  e = e - grow + 0.012 * rn * smoothstep(0.0, 0.05, grow);
  float hole = 1.0 - smoothstep(-0.0025, 0.0025, e);
  float fade = 1.0 - smoothstep(0.7, 1.0, p);
  float rim = exp(-abs(e) * 260.0);
  float singe = exp(-max(e, 0.0) * 70.0) * smoothstep(0.0, 0.004, -e + 0.02) * fade;
  vec4 A = getFromColor(uv), B = getToColor(uv);
  vec3 a = A.rgb * (1.0 - 0.55 * singe * (1.0 - rim));
  a += heat * vec3(0.55, 0.62, 0.75);
  a += rim * fade * mix(vec3(1.0, 0.55, 0.25), vec3(0.85, 0.92, 1.0), clamp(heat * 2.0, 0.0, 1.0));
  vec3 b = B.rgb + (heat * 0.8 + 0.6 * rim) * fade * vec3(0.8, 0.88, 1.0) * exp(min(e, 0.0) * 80.0);
  return vec4(clamp(mix(a, b, hole), 0.0, 1.0), mix(A.a, B.a, hole));
}
