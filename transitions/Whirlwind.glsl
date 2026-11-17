// Author: gre
// License: MIT
// Description: A whirlwind crosses the frame from left to right: it winds the outgoing image into a spiral around its eye and draws it inward as it passes, and leaves the incoming image in its wake, which unwinds and straightens out behind it
// Tags: swirl, wind, vortex, directional, distort

// @range(0.5, 3) Turns the picture makes around the eye
uniform float turns; // = 1.6
// @range(0.15, 0.6) Radius of the whirlwind, as a fraction of the frame's shorter side
uniform float size; // = 0.32

const float PI = 3.141592653589793;
const int TAPS = 16;
// the front leans back at the top like a trailing funnel
const float LEAN = 0.35;
// nominal pixel footprint for the radial anti-aliasing (no resolution uniform)
const float PX = 0.004;

vec2 mirrored(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

vec4 transition(vec2 uv) {
  float t = progress, R = ratio;
  vec2 Q = vec2(uv.x * R, uv.y);
  float S = size * min(R, 1.0);
  // just far enough out that the front starts and ends off screen
  float reach = 0.5 * LEAN + 0.01;
  // the eye hurries near the edges, where little is seen, and lingers mid-frame
  float x = t + 0.3 * sin(2.0 * PI * t) / (2.0 * PI);
  vec2 c = vec2(mix(-reach, R + reach, x), 0.5 + 0.08 * sin(t * 6.0));
  // spins only once the eye is well inside: near an edge the twist would pull mirrored pixels from beyond it, showing a fold
  float ramp = min(2.0 * S, 0.7 * R);
  float g = smoothstep(0.0, ramp, c.x) * smoothstep(0.0, ramp, R - c.x);
  vec2 d = Q - c;
  float s2 = S * S;
  float k = s2 / (dot(d, d) + s2);
  float k3 = k * k * k;
  float kp = k3 * g;
  float A = 2.0 * PI * turns;
  float th = A * kp;
  float inflow = 1.0 + 0.5 * kp;
  // motion blur along the spin plus |dth/dr| * PX (dth/dr = 6 A g r k^4 / S^2), which hides the ring aliasing in the core
  float spread = min(0.15 * th * k + PX * 6.0 * A * g * length(d) * k3 * k / s2, 1.0);
  vec4 col = vec4(0.0);
  float wsum = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float u = float(i) / float(TAPS - 1) - 0.5;
    float a = th + spread * u;
    float w = 1.0 - abs(u);
    float ca = cos(a), sa = sin(a);
    vec2 s = c + mat2(ca, -sa, sa, ca) * d * inflow;
    float f = s.x - c.x + LEAN * (s.y - 0.5);
    vec2 su = mirrored(vec2(s.x / R, s.y));
    vec4 v = mix(getToColor(su), getFromColor(su), smoothstep(-0.004, 0.004, f));
    // averaged premultiplied so transparent texels don't darken the blur
    col += w * vec4(v.rgb * v.a, v.a);
    wsum += w;
  }
  col /= wsum;
  return vec4(col.rgb / max(col.a, 1e-5) * (1.0 - 0.3 * kp * k), col.a);
}
