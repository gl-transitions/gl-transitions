// Author: gre
// License: MIT
// Description: The outgoing picture turns into a sand drawing on a glowing light table; gusts of wind lift the grains, which drift and curl in eddies all over the frame and settle again into the incoming picture's sand drawing, which then takes its colours back
// Tags: sand, wind, particles, organic, dissolve

// @color Light shining through the bare glass
uniform vec4 light; // = vec4(1.0, 0.78, 0.42, 1.0)
// @color Colour of the thickest sand
uniform vec4 sand; // = vec4(0.2, 0.11, 0.05, 1.0)
// @range(0, 1) How far the wind carries the grains, in frame heights
uniform float drift; // = 0.5
// @range(0, 2) Strength of the eddies compared with the steady wind
uniform float swirl; // = 1.0

float sdHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 = fract(p3 + dot(p3, p3.yzx + 33.33));
  return fract((p3.x + p3.y) * p3.z);
}

float sdNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(sdHash(i), sdHash(i + vec2(1.0, 0.0)), f.x),
    mix(sdHash(i + vec2(0.0, 1.0)), sdHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// counter-rotating vortices from the stream function sin(x)sin(y): divergence-free, so the flow neither piles sand up nor thins it out
vec2 sdEddies(vec2 q, float k, mat2 r, vec2 phase) {
  vec2 x = k * (r * q) + phase;
  return vec2(sin(x.x) * cos(x.y), -cos(x.x) * sin(x.y)) * r;
}

vec2 sdWind(vec2 q, float time) {
  q -= vec2(0.55, 0.23) * time;
  return vec2(0.92, 0.38) + swirl * (1.1 * sdEddies(q, 4.3, mat2(0.8776, 0.4794, -0.4794, 0.8776), vec2(0.7, 2.1)) + 0.45 * sdEddies(q, 9.1, mat2(0.6967, -0.7174, 0.7174, 0.6967), vec2(4.0, 1.3)));
}

vec2 sdFold(vec2 q) {
  return 1.0 - abs(1.0 - mod(vec2(q.x / ratio, q.y), 2.0));
}

float sdLuma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float sdDark(vec4 c) {
  return (0.03 + 0.97 * smoothstep(0.95, 0.1, sdLuma(c.rgb))) * c.a;
}

// smaller grains travel farther: averaging the size classes smears the drawing into streaks along the flow
float sdSand(vec2 q, float t, float swap, bool incoming) {
  float sum = 0.0;
  vec2 p = q;
  mat2 turn = mat2(-0.1288, -0.9917, 0.9917, -0.1288);
  for (int i = 0; i < 8; i++) {
    p -= sdWind(p, t * (1.0 - 0.125 * float(i))) * (t * 0.19);
    turn = turn * mat2(-0.1288, 0.9917, -0.9917, -0.1288);
    if (i >= 2) {
      float fi = float(i);
      float cells = 60.0 + 16.0 * fi;
      // each size class on its own turned lattice so no grid shows through
      vec2 g = turn * p * cells;
      vec2 c = floor(g) + fi * 37.0 + (incoming ? 400.0 : 0.0);
      vec2 centre = floor(g) + 0.15 + 0.7 * vec2(sdHash(c), sdHash(c + 17.3));
      float r = 0.2 + 0.2 * sdHash(c + 5.9);
      float grain = 1.0 - smoothstep(r - 0.12, r + 0.04, length(g - centre));
      vec4 col = incoming ? getToColor(sdFold(p)) : getFromColor(sdFold(p));
      float lift = smoothstep(-0.1, 0.1, swap - 0.15 - 0.7 * sdNoise(p * 7.0 + fi * 5.3 + (incoming ? 9.0 : 0.0)));
      sum += sdDark(col) * (0.6 + 1.6 * grain) * (incoming ? lift : 1.0 - lift);
    }
  }
  return sum / 6.0;
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float u = smoothstep(0.06, 0.82, progress);
  float gust = 0.6 + 0.8 * sdNoise(q * 1.6 - vec2(1.4, 0.6) * u + vec2(3.1, 7.7));
  float swap = smoothstep(0.2, 0.8, u + 0.25 * (sdNoise(q * 2.3 + 11.0) - 0.5));
  float th = sdSand(q, drift * gust * u * u, swap, false) + sdSand(q, -drift * gust * (1.0 - u) * (1.0 - u), swap, true);

  float f = 1.0 - exp(-2.2 * th);
  // thick sand forms first and the light shines back through the thinnest sand first
  float m1 = smoothstep(0.0, 0.1, progress - 0.05 * (1.0 - f));
  float m2 = smoothstep(0.0, 1.0, (progress - 0.8 - 0.08 * f) / 0.11);
  // whitening the light as colours return keeps the amber from muddying them
  vec3 glow = mix(light.rgb, vec3(sdLuma(light.rgb)), 0.7 * m2) * (1.0 - 0.4 * dot(uv - 0.5, uv - 0.5));
  vec3 sandImg = mix(glow, sand.rgb, f) * (1.0 + 0.5 * f * (1.0 - f) * vec3(0.25, -0.05, -0.35));

  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float sandA = mix(a.a, b.a, swap);
  vec4 c = mix(mix(vec4(a.rgb * a.a, a.a), vec4(sandImg * sandA, sandA), m1), vec4(b.rgb * b.a, b.a), m2);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
