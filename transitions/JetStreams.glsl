// Author: gre
// License: MIT
// Description: Winds blow in opposite directions along rows of the outgoing picture, drawing it into the bands, curls and oval storm of a giant planet; the bands take the colors of the incoming picture strand by strand, and the same winds carry it into place
// Tags: liquid, wind, planet, swirl, distort

// @param Number of bands of wind
// @range(2, 10)
uniform float bands; // = 5.0
// @param How far the winds blow
// @range(0.2, 1.5)
uniform float wind; // = 1.0
// @param Strength of the oval storm
// @range(0, 1.5)
uniform float storm; // = 1.0

const int STEPS = 13;
const vec2 EYE = vec2(0.14, -0.13);
const vec2 OVAL = vec2(0.2, 0.105);

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

vec2 mirrored(vec2 u) {
  return 1.0 - abs(1.0 - mod(u, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// analytic curl of a stream function: jets, rows of eddies, ripples, one oval storm
vec2 flow(vec2 q) {
  float k = 3.14159265 * bands;
  float sk = sin(k * q.y), ck = cos(k * q.y);
  float h = 2.0 * bands * q.y;
  float ph = 13.0 * q.x + 1.3 * sin(h);
  float sp = 0.009 * sin(ph), cp = 0.009 * cos(ph);
  float f = (0.62 / k + sp) * ck;
  vec2 g = vec2(13.0 * cp * ck, 2.6 * bands * cos(h) * cp * ck - (0.62 + k * sp) * sk);
  vec2 m = 0.00175 * sin(vec2(26.0 * q.x - 29.0 * q.y, 20.0 * q.x + 33.0 * q.y) + 0.7);
  g += vec2(20.0 * m.y - 26.0 * m.x, 29.0 * m.x + 33.0 * m.y);
  vec2 s = (q - EYE) / OVAL;
  float u = exp(-0.35 * dot(s, s));
  float w = u * u * min(storm, 1.0);
  g = g * (1.0 - w) + (f * 0.7 * w - 0.1 * storm * u * u * u) * 2.0 * s / OVAL;
  return vec2(g.y, -g.x);
}

vec2 carry(vec2 q, float t) {
  float dt = t / float(STEPS);
  // midpoint steps, each guessing its midpoint from the step before
  vec2 v = flow(q);
  for (int i = 0; i < STEPS; i++) {
    v = flow(q + 0.5 * dt * v);
    q += dt * v;
  }
  return q;
}

vec4 transition(vec2 uv) {
  float t = mix(progress, smoothstep(0.0, 1.0, progress), 0.8);
  float span = 2.6 * wind;
  vec2 asp = vec2(ratio, 1.0);
  vec2 x = (uv - 0.5) * asp;
  vec2 qa = carry(x, -span * t);
  vec2 qb = carry(x, span * (1.0 - t));
  float calm = 4.0 * progress * (1.0 - progress);
  // along the winds, against filaments thinner than a pixel
  float smear = 0.045 * calm * calm;
  vec4 a = vec4(0.0), b = vec4(0.0);
  for (int j = -4; j <= 4; j++) {
    vec2 o = vec2(float(j) * smear * 0.25, 0.0);
    a += pm(getFromColor(mirrored((qa + o) / asp + 0.5)));
    b += pm(getToColor(mirrored((qb + o) / asp + 0.5)));
  }
  float n = 0.65 * noise(qa * vec2(2.2, 17.0)) + 0.35 * noise(qb * vec2(3.0, 31.0) + 9.0);
  float e = mix(-0.25, 1.25, smoothstep(0.15, 0.85, progress));
  vec4 col = mix(a, b, smoothstep(n - 0.22, n + 0.22, e)) / 9.0;
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
