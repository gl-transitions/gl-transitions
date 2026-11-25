// Author: gre
// License: MIT
// Description: On each of four beats the outgoing picture multiplies into nine times as many copies of itself, up to thousands, and the copies take on the colors of their place in the incoming picture until the crowd draws it; a last beat brings in its detail
// Tags: copies, mosaic, grid, zoom, beat

// @range(0, 1) How strongly the copies are colored by the incoming picture
uniform float tint; // = 1.0
// @range(0, 2) Overshoot of each beat
uniform float bounce; // = 0.9
// @range(0, 0.2) Zoom punch of the last beat
uniform float punch; // = 0.05

vec4 fromPre(vec2 p) {
  vec4 c = getFromColor(p);
  return vec4(c.rgb * c.a, c.a);
}

vec4 toPre(vec2 p) {
  vec4 c = getToColor(1.0 - abs(1.0 - abs(p)));
  return vec4(c.rgb * c.a, c.a);
}

float hit(float t0, float d) {
  float x = clamp((progress - t0) / d, 0.0, 1.0) - 1.0;
  return 1.0 + x * x * ((1.0 + bounce) * x + bounce);
}

vec4 transition(vec2 uv) {
  float e = hit(0.04, 0.17) + hit(0.22, 0.17) + hit(0.42, 0.17) + hit(0.62, 0.16);
  float settle = clamp((1.0 - progress) / 0.17, 0.0, 1.0);
  vec2 p = (uv - 0.5) * (1.0 - punch * smoothstep(0.77, 0.83, progress) * settle * settle * settle) + 0.5;

  // tripling keeps the middle copy whole on every beat
  float s = exp(e * log(3.0));
  vec2 g = (p - 0.5) * s + 0.5;
  vec2 n = floor(g - 0.5);
  // each copy keeps the color of its place but shades into its neighbors', or the copies show as flat blocks
  vec2 w = g - 0.5 - n;
  w = mix(smoothstep(0.1, 0.9, w), w, smoothstep(2.0, 4.0, e));

  vec4 a = vec4(0.0);
  for (int j = 0; j < 3; j++) {
    for (int i = 0; i < 3; i++) a += fromPre(fract(g + (vec2(float(i), float(j)) - 1.0) * 0.00055 * (s - 1.0))) / 9.0;
  }
  vec4 b = vec4(0.0);
  for (int j = 0; j < 4; j++) {
    for (int i = 0; i < 4; i++) {
      vec2 o = vec2(float(i), float(j));
      vec2 q = 0.5 * mix(1.0 - w, w, step(1.5, o));
      b += q.x * q.y * toPre((n - 0.25 + 0.5 * o) / s + 0.5);
    }
  }
  vec4 m = vec4(0.0);
  for (int j = 0; j < 2; j++) {
    for (int i = 0; i < 2; i++) m += 0.25 * fromPre(0.25 + 0.5 * vec2(float(i), float(j)));
  }

  vec4 d = (a - m) * mix(1.0, 0.35, smoothstep(2.0, 4.0, e));
  d.rgb = mix(d.rgb, vec3(dot(d.rgb, vec3(0.299, 0.587, 0.114))), 0.4);
  vec4 c = mix(a, b + d, tint * smoothstep(0.3, 2.0, e));
  c = mix(c, toPre(p), smoothstep(0.78, 0.86, progress));
  float alpha = clamp(c.a, 0.0, 1.0);
  return vec4(clamp(c.rgb / max(alpha, 1e-4), 0.0, 1.0) * step(1e-4, alpha), alpha);
}
