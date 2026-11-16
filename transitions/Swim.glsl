// Author: gre
// License: MIT
// Description: The outgoing image turns into a fish and swims out of the frame head first: its body narrows into a forked tail, a bending wave runs from its head to its tail and swings wider beat by beat, lighting and shading its flanks as it bends and driving it faster until it is gone, revealing the incoming image under its soft shadow
// Tags: organic, swim, wave, bend, directional, shadow

// @range(0.0, 0.25) How far the tail swings, as a part of the frame's short side
uniform float swing; // = 0.12
// @range(1.0, 4.0) Number of tail beats
uniform float beats; // = 2.5
// @range(0.0, 0.9) How much the body narrows toward the tail
uniform float taper; // = 0.65
// @range(0.0, 1.0) Strength of the shading on the bends and of the shadow
uniform float shading; // = 0.7

const float PI = 3.141592653589793;
const float AA = 0.003;
const float HEAD = 0.38;
const float PEDUNCLE = 0.8;
const float FORK = 0.17;
const float K = 2.0 * PI * 0.8;

float wave(float u, float amp, float ph) {
  return amp * (0.1 + 0.9 * u * u) * sin(K * u - ph);
}

float dwave(float u, float amp, float ph) {
  return amp * (1.8 * u * sin(K * u - ph) + (0.1 + 0.9 * u * u) * K * cos(K * u - ph));
}

float ddwave(float u, float amp, float ph) {
  float a = K * u - ph;
  return amp * (1.8 * sin(a) + 3.6 * u * K * cos(a) - (0.1 + 0.9 * u * u) * K * K * sin(a));
}

// the tail fin stays straight, continuing the peduncle, so the bent body never folds over itself
float centerline(float u, float amp, float ph) {
  return wave(clamp(u, -0.1, PEDUNCLE), amp, ph) + dwave(PEDUNCLE, amp, ph) * max(u - PEDUNCLE, 0.0);
}

float slope(float u, float amp, float ph) {
  return u < -0.1 ? 0.0 : dwave(min(u, PEDUNCLE), amp, ph);
}

float trunk(float u) {
  return 1.0 - taper * smoothstep(0.3, PEDUNCLE, u);
}

// outline half width along the body, 1 = the full frame
float profile(float u, float m) {
  float h = pow(sin(0.5 * PI * clamp(u / HEAD, 0.0, 1.0)), 0.6);
  float body = trunk(u);
  float fin = mix(1.0 - taper, 0.95, smoothstep(PEDUNCLE, 0.97, u));
  float w = u < PEDUNCLE ? h * body : max(body, fin);
  return mix(1.0, w, m);
}

// body coordinates of P: (along, across) in short sides of the frame, found by projecting P on the bent centerline
vec2 bodyCoords(vec2 P, float head, float len, float amp, float ph) {
  float u = (P.x - head) / len;
  for (int i = 0; i < 4; i++) {
    vec2 T = normalize(vec2(len, slope(u, amp, ph)));
    u += dot(P - vec2(head + u * len, 0.5 + centerline(u, amp, ph)), T) / len;
  }
  vec2 T = normalize(vec2(len, slope(u, amp, ph)));
  return vec2(u, dot(P - vec2(head + u * len, 0.5 + centerline(u, amp, ph)), vec2(-T.y, T.x)));
}

// approximate signed distance to the fish, in short sides of the frame
float fish(vec2 b, float len, float hh, float m) {
  float e = 0.002;
  float hw = hh * profile(b.x, m);
  float dw = clamp(hh * (profile(b.x + e, m) - profile(b.x - e, m)) / (2.0 * e * len), -4.0, 4.0);
  float side = (abs(b.y) - hw) / sqrt(1.0 + dw * dw);
  float tail = len * (1.0 - m * FORK * (1.0 - min(abs(b.y) / max(hw, 1e-3), 1.0)));
  float s = b.x * len;
  return max(max(side, -s), s - tail) - 2.0 * AA * (1.0 - m);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float t = progress;
  bool tall = ratio < 1.0;
  float L = tall ? 1.0 / ratio : ratio;
  vec2 P = tall ? vec2((1.0 - uv.y) * L, uv.x) : vec2(uv.x * L, uv.y);

  float m = smoothstep(0.0, 0.35, t);
  float len = L * mix(1.0, 0.6, m);
  float hh = 0.5 * mix(1.0, 0.6, m);
  // a short body bends tighter for the same swing, so near-square frames swing less
  float amp = swing * min(1.0, L / 1.6) * smoothstep(0.0, 0.6, t);
  float g = t * (0.5 + 0.5 * t);
  float ph = 2.0 * PI * beats * g;
  float travel = 0.6 * L + 0.3 + swing;
  // the head draws back into the frame first; each tail beat adds a small surge to the acceleration
  float head = 0.12 * L * m * (1.0 - t) - travel * (pow(t, 2.4) + 0.012 * sin(4.0 * PI * beats * g) * t * (1.0 - t));

  vec2 b = bodyCoords(P, head, len, amp, ph);
  float inBody = 1.0 - smoothstep(-AA, AA, fish(b, len, hh, m));

  float u = b.x;
  float hw = hh * profile(u, m);
  float body = hh * mix(1.0, trunk(u), m);
  vec2 src = mirror(vec2(u, 0.5 + 0.5 * b.y / max(hw, 0.6 * body)));
  vec4 c = getFromColor(tall ? vec2(src.y, 1.0 - src.x) : src);

  vec2 T = normalize(vec2(len, slope(u, amp, ph)));
  vec2 lat = tall ? vec2(T.x, T.y) : vec2(-T.y, T.x);
  float vn = clamp(b.y / max(body, 1e-3), -1.0, 1.0);
  float fin = smoothstep(PEDUNCLE - 0.05, PEDUNCLE + 0.05, u);
  vec3 N = normalize(vec3(lat * vn * (1.0 - fin), mix(sqrt(1.0 - vn * vn), 1.0, fin)));
  vec3 Ld = normalize(vec3(-0.35, 0.55, 0.75));
  float diff = max(dot(N, Ld), 0.0) / Ld.z;
  float spec = pow(max(dot(reflect(-Ld, N), vec3(0.0, 0.0, 1.0)), 0.0), 16.0);
  float k = shading * m;
  float curv = ddwave(clamp(u, 0.0, PEDUNCLE), amp, ph) / (len * len);
  // the inside of a bend is creased and darker, the outside stretched and lighter
  float crease = clamp(0.25 * curv * vn, -1.0, 1.0) * (1.0 - fin);
  c.rgb = c.rgb * mix(1.0, min(diff, 1.1) * (1.0 - 0.3 * crease), 0.7 * k) + 0.08 * k * spec * c.a;

  vec2 off = 0.06 * m * (tall ? vec2(1.0, 1.0) : vec2(1.0, -1.0));
  // the shadow is soft, so moving it in the body frame found for P is close enough
  float sd = fish(b - vec2(dot(off, T) / len, dot(off, vec2(-T.y, T.x))), len, hh, m);
  vec4 bg = getToColor(uv);
  bg.rgb *= 1.0 - 0.5 * k * (1.0 - smoothstep(-0.04, 0.08, sd));

  return mix(bg, c, inBody * (1.0 - 0.15 * m * fin));
}
