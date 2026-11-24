// Author: gre
// License: MIT
// Description: Fine, slowly turning guide circles pack the outgoing picture into an Apollonian gasket; the biggest circles open first, each swelling from its own center into a bright-rimmed window on the incoming picture, then the next sizes follow, faster and faster down into the ever smaller gaps
// Tags: circles, fractal, geometry, math, reveal

// @range(0, 1) Depth of the windows: zoom of the incoming picture and inner shadow
uniform float depth; // = 0.6
// @color Guide lines and rims of the circles
uniform vec4 lineColor; // = vec4(1.0, 1.0, 1.0, 0.8)

const float R1 = 0.46410162; // 2 * sqrt(3) - 3: three equal circles inside the unit circle

vec2 rot(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float Rd = 0.5 * length(asp) * 1.04;
  float turn = 0.35 - 0.25 * p;
  vec2 z = rot((uv - 0.5) * asp / Rd, turn);

  // inverting at the tangent point of the outer circle and the bottom circle turns the gasket into the strip packing 0<Y<1
  vec2 a = vec2(0.0, -1.0);
  float k = 2.0 * R1 / (1.0 - R1);
  vec2 d = z - a;
  vec2 w = d * k / max(dot(d, d), 1e-6);
  vec2 P = vec2(w.x + 0.5, w.y - 0.5 * k);
  vec2 cc = vec2(0.0, -(1.0 - R1));
  float cr = R1;
  vec3 steps[12];
  int level = -1;
  if (P.y <= 1.0) {
    for (int i = 0; i < 12; i++) {
      float n = floor(P.x + 0.5);
      P.x -= n;
      vec2 o = P - vec2(0.0, 0.5);
      steps[i] = vec3(n, 0.0, 0.0);
      if (dot(o, o) < 0.25) {
        level = i;
        break;
      }
      steps[i].y = step(0.5, P.y);
      if (P.y > 0.5) P.y = 1.0 - P.y;
      steps[i].z = step(P.x, 0.0);
      P.x = abs(P.x);
      P /= max(dot(P, P), 1e-6);
    }
    // carry the found circle back through the folds to get its true center and radius
    vec2 c = vec2(0.0, 0.5);
    float r = 0.5;
    for (int j = 0; j < 12; j++) {
      int i = 11 - j;
      // i is no constant-index expression in strict GLSL ES 1.00, 11 - j is
      vec3 s = steps[11 - j];
      if (i < level) {
        float q = dot(c, c) - r * r;
        c /= q;
        r /= abs(q);
        if (s.z > 0.5) c.x = -c.x;
        if (s.y > 0.5) c.y = 1.0 - c.y;
      }
      if (i <= level) c.x += s.x;
    }
    c = vec2(c.x - 0.5, c.y + 0.5 * k);
    float q = dot(c, c) - r * r;
    cc = a + k * c / q;
    cr = level < 0 ? 1e-4 : k * r / abs(q);
  }
  float rad = cr * Rd;
  float rho = length(z - cc) / cr;

  float t = clamp(p / 0.95, 0.0, 1.0);
  t *= sqrt(t);
  float thr = mix(log(R1 * Rd * 1.02), log(0.003), t);
  float local = clamp(log(rad) - thr, 0.0, 1.0);
  float fill = 1.0 - pow(1.0 - local, 2.5);
  float aa = 0.0025;
  // a full circle reaches aa past its edge, or a seam would stay along it
  float e = (fill - rho) * rad + aa * smoothstep(0.85, 1.0, fill);
  float m = smoothstep(-aa, aa, e) * smoothstep(0.0, 0.05, fill);
  // the dust in the last gaps has no circle of its own
  float dust = smoothstep(0.78, 0.99, p);
  float open = 1.0 - smoothstep(0.75, 1.0, local);

  float line = 1.0 - smoothstep(0.0005, 0.0025, abs(1.0 - rho) * rad);
  line *= smoothstep(0.0, 0.12, p) * smoothstep(thr - 2.0, thr, log(rad)) * smoothstep(0.002, 0.012, rad) * (1.0 - m) * (1.0 - dust);
  float rw = 0.0015 + 0.004 * smoothstep(0.0, 0.2, rad);
  float rim = (1.0 - smoothstep(rw - 0.0015, rw + 0.0015, abs(e))) * smoothstep(0.0, 0.03, local) * open * smoothstep(0.002, 0.02, rad);

  vec2 center = clamp(rot(cc, -turn) * Rd / asp + 0.5, 0.0, 1.0);
  vec2 tuv = mix(uv, center, (level < 0 ? 0.0 : 0.3) * depth * (1.0 - smoothstep(0.0, 1.0, fill)) * (1.0 - dust));
  vec4 from = getFromColor(uv);
  vec4 to = getToColor(tuv);
  // light from the top left: the upper left edge of a window casts its shadow inside
  vec2 dir = rot(z - cc, -turn) / max(cr * rho, 1e-6);
  float inner = (1.0 - smoothstep(0.0, 0.07 * smoothstep(0.0, 0.15, rad) + 1e-4, e)) * (0.6 + 0.4 * dot(dir, vec2(-0.6, 0.8)));
  to.rgb *= 1.0 - 0.6 * depth * inner * open * (1.0 - dust);

  vec4 c = mix(vec4(from.rgb * from.a, from.a), vec4(to.rgb * to.a, to.a), max(m, dust));
  c = mix(c, vec4(lineColor.rgb, 1.0), lineColor.a * max(line, rim * (1.0 - dust)));
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
