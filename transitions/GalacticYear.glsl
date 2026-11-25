// Author: gre
// License: MIT
// Description: The outgoing picture turns into a leaning galaxy of its own colors, its heart setting off first and its rim last; the incoming picture is already in the bright heart and opens outward as every circle finishes its one full turn
// Tags: galaxy, spiral, rotate, space, distort
// Preview: 0.5

// @range(0, 1) How far the galaxy leans away from the viewer
uniform float lean; // = 0.5
// @range(0, 2) Brightness of the stars
uniform float stars; // = 1.0
// @range(0, 2) Brightness of the heart
uniform float glow; // = 1.0

const int TAPS = 14;
const float TAU = 6.2831853;
// how much later than the heart the rim sets off
const float DELAY = 0.3;

vec2 hash(vec2 p) {
  vec3 a = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  a += dot(a, a.yzx + 33.33);
  return fract((a.xx + a.yz) * a.zy);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec2 turn(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x + s * v.y, c * v.y - s * v.x);
}

// part of its one full turn that a circle has made
float lap(float r, float t) {
  float x = clamp((t - DELAY * sqrt(r)) / (1.0 - DELAY), 0.0, 1.0);
  return smoothstep(0.0, 1.0, x * (1.35 - 0.35 * x));
}

vec4 look(vec2 p, float k) {
  vec2 q = mirror(turn(p, TAU * k) / vec2(ratio, 1.0) + 0.5);
  return mix(pm(getFromColor(q)), pm(getToColor(q)), smoothstep(0.3, 0.6, k));
}

vec4 transition(vec2 uv) {
  float e = sin(3.14159265 * progress);
  e *= e;
  vec2 asp = vec2(ratio, 1.0);
  vec2 p = turn((uv - 0.5) * asp, 1.2 - 1.8 * progress);
  p *= vec2(1.0 / (1.0 + lean * e), 1.0 + lean * e);
  p = turn(p, 1.8 * progress - 1.2);
  float r = length(p), rr = min(2.0 * r / length(asp), 1.0);

  vec4 c = vec4(0.0);
  for (int i = 0; i < TAPS; i++) c += look(p, lap(rr, progress + ((float(i) + 0.5) / float(TAPS) - 0.5) * 0.04 * e));
  c /= float(TAPS);
  if (c.a <= 0.0) return vec4(0.0);
  c.rgb /= c.a;

  float k = lap(rr, progress);
  vec2 g = turn(p, TAU * k);
  float sky = 0.0;
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    vec2 v = g * (48.0 + 40.0 * fi), id = floor(v), h = hash(id + 17.0 * fi);
    float mag = smoothstep(0.8 - 0.5 * exp(-r * 5.0), 1.0, h.y);
    sky += mag * (1.0 - smoothstep(0.0, 0.3, length(v - id - 0.3 - 0.4 * h)));
  }
  float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  c.rgb *= 1.0 - 0.4 * e * smoothstep(0.1, 0.9, rr) * (1.0 - lum);
  // on pale areas stars would only be white specks
  float lit = stars * sky * 4.0 * k * (1.0 - k) * (0.5 + 2.5 * lum) * (1.0 - smoothstep(0.35, 0.75, lum));
  c.rgb += e * (lit * c.rgb + glow * 0.6 * exp(-r * 8.0) * vec3(1.0, 0.86, 0.62));
  return vec4(min(c.rgb, 1.0), c.a);
}
