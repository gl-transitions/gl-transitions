// Author: gre
// License: MIT
// Description: Two small dark bodies appear in the outgoing picture and circle each other, bending it around them; they spiral in faster and faster, their wake throwing out two winding arms that carry the incoming picture, and when they merge a burst runs outward and the arms tighten into rings that shake the picture and die away
// Tags: space, black-hole, spiral, waves, distort
// Preview: 0.5

// @range(0, 0.1) How far the waves push the pictures
uniform float strength; // = 0.05
// @range(1, 4) Number of turns before the bodies merge
uniform float turns; // = 2.0
// @range(0, 1) Brightness of the burst when the bodies merge
uniform float burst; // = 0.45
// @color Color of the bodies
uniform vec4 body; // = vec4(0.0, 0.0, 0.0, 1.0)

const float PI = 3.14159265;
const float MERGE = 0.56;
const float SOFT = 0.08;

float orbit(float x) {
  float end = pow(SOFT, 0.55);
  float n = pow(MERGE + SOFT, 0.55) - end;
  // the frequency reached at the merger is kept while the waves ring down
  return 2.0 * PI * turns / n * (0.55 * end / SOFT * max(x - MERGE, 0.0) + end - pow(max(MERGE - x, 0.0) + SOFT, 0.55));
}

vec4 scene(vec2 z, float p, vec2 asp, vec2 c1, float on, float M) {
  float r = length(z);
  vec2 d = z / max(r, 1e-4);
  // the waves leave the center and take time to reach the borders
  float x = p - 0.22 * r;
  float o2 = 2.0 * orbit(p - 0.4 * r);
  vec2 d2 = vec2(d.x * d.x - d.y * d.y, 2.0 * d.x * d.y);
  vec2 w = vec2(d2.x * cos(o2) + d2.y * sin(o2), d2.y * cos(o2) - d2.x * sin(o2));
  float after = max(x - MERGE, 0.0);
  float amp = on * exp(-after * 9.0) * (0.25 + 0.75 * smoothstep(0.1, MERGE, x)) / (0.7 + r);
  float k = smoothstep(0.42, 0.58, smoothstep(0.2, 0.68, x) + 0.6 * w.x * amp);
  vec2 q = z + strength * amp * (d * w.x + vec2(-d.y, d.x) * w.y) * smoothstep(0.0, 0.15, r);
  float front = (x - MERGE - 0.01) / 0.022;
  float flash = burst * on * exp(-front * front) / (0.6 + 1.4 * r);
  q -= 0.6 * strength * flash * front * d;
  vec2 g1 = z - c1;
  vec2 g2 = z + c1;
  q -= M * (g1 / (dot(g1, g1) + 1e-5) + g2 / (dot(g2, g2) + 1e-5));
  vec2 s = 1.0 - abs(1.0 - mod(q / asp + 0.5, 2.0));
  vec4 a = getFromColor(s), b = getToColor(s);
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), k);
  c.rgb = c.rgb * (1.0 + 0.35 * amp * w.y + 0.5 * flash) + 0.25 * flash * c.a;
  float hr = 0.75 * sqrt(M * (1.0 + exp(-dot(c1, c1) * 500.0)));
  float dark = min(1.0, M * 2000.0) * (1.0 - smoothstep(hr * 0.88, hr + 1e-5, min(length(g1), length(g2))));
  return mix(c, vec4(body.rgb * body.a, body.a), dark);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float on = smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.72, 1.0, p));
  float u = max(MERGE - p, 0.0) / MERGE;
  float o = orbit(p);
  vec2 c1 = 0.3 * min(1.0, ratio) * pow(u, 0.4) * smoothstep(0.0, 0.2, p) * vec2(cos(o), sin(o));
  float M = 0.0027 * on * (1.0 - smoothstep(0.62, 0.85, p));
  vec4 sum = vec4(0.0);
  float aa = 0.0022 * on;
  for (int i = 0; i < 4; i++) {
    vec2 e = vec2(mod(float(i), 2.0), floor(float(i) / 2.0 + 0.01)) - 0.5;
    sum += 0.25 * scene((uv - 0.5) * asp + aa * e, p, asp, c1, on, M);
  }
  return sum.a > 0.0 ? vec4(min(sum.rgb / sum.a, 1.0), sum.a) : vec4(0.0);
}
