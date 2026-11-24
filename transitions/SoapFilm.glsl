// Author: gre
// License: MIT
// Description: The outgoing picture becomes a reflection on a soap film stretched across the frame: rainbow interference bands swirl over it in slow eddies that carry the reflection round with them, and as the film drains thin from the top it turns clear in patches, revealing the incoming picture behind it
// Tags: soap, film, bubble, iridescent, liquid, swirl, light, dissolve

// @range(0, 1) How fast the eddies turn, and how far they drag the pictures round
uniform float swirl; // = 0.4
// @range(0, 1) Strength of the rainbow interference colours
uniform float iridescence; // = 0.8

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

// curl of sin*sin stream functions: divergence-free eddies
vec2 flow(vec2 q) {
  mat2 r = mat2(0.88, 0.48, -0.48, 0.88);
  vec2 a = (r * q) * vec2(5.0, 4.2) + vec2(0.0, 0.7);
  vec2 v = vec2(0.84 * sin(a.x) * cos(a.y), -cos(a.x) * sin(a.y)) * r;
  vec2 b = q * vec2(2.3, 2.9) + 1.7;
  return v + vec2(-0.6 * sin(b.x) * cos(b.y), 0.476 * cos(b.x) * sin(b.y));
}

vec2 advect(vec2 q, float t) {
  vec2 o = q;
  for (int i = 0; i < 5; i++) o -= flow(o) * (t / 5.0);
  return o - q;
}

// offsets kept apart from uv so a zero drift samples uv exactly
vec2 toUv(vec2 uv, vec2 o) {
  return 1.0 - abs(1.0 - mod(uv + o / vec2(ratio, 1.0), 2.0));
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float p = progress;
  vec2 oa = advect(q, swirl * p * p * 1.6);
  vec2 ob = advect(q, -swirl * (1.0 - p) * (1.0 - p) * 1.6);
  vec2 qt = q + advect(q, 0.3 + (0.3 + swirl) * 1.6 * p);

  float nn = 0.6 * noise(qt * 3.0) + 0.3 * noise(qt * 6.5 + 3.1) + 0.1 * noise(qt * 13.0 - 5.7);
  // film left to drain: thinner toward the top, gone everywhere by p = 1
  float h = clamp(1.1 - 1.9 * p + 0.8 * (nn - 0.5) - 0.3 * (uv.y - 0.5), 0.0, 1.0);
  // thickness in micrometres; reflectance of a thin film of water at each wavelength
  float d = 0.85 * h;
  vec3 refl = sin(8.357 * d / vec3(0.62, 0.53, 0.45));
  refl *= refl;
  // higher orders wash out toward pastel, as the spectrum overlaps itself
  refl = mix(refl, vec3(dot(refl, vec3(0.3333))), 0.65 * smoothstep(0.35, 0.85, d));

  float clear = 1.0 - smoothstep(0.0, 0.3, h);
  float film = iridescence * smoothstep(0.0, 0.35, p) * (1.0 - clear);
  vec4 a = getFromColor(toUv(uv, oa));
  vec4 b = getToColor(toUv(uv, ob));
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), clear);
  c.rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  // a thinning film fades to clear instead of darkening into black film
  vec3 tint = c.rgb * mix(vec3(1.0), 0.6 + 0.75 * refl, smoothstep(0.08, 0.3, d)) + 0.14 * refl;
  c.rgb = mix(c.rgb, tint, film);
  return c;
}
