// Author: gre
// License: MIT
// Description: The outgoing image turns into the silky, wavy fibers of a polished stone; as the stone tilts, a band of light travels along the bends of the fibers, which show the incoming image once it has passed, and smooth into it
// Tags: stone, fibers, shine, waves, texture, organic
// Preview: 0.5

// @range(0, 2) Strength of the relief
uniform float strength; // = 1.0
// @range(30, 120) Number of fibers over the height of the frame
uniform float fibers; // = 62.0

vec2 hash2(vec2 p) {
  vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x), mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + 1.0).x, f.x), f.y);
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

float bend(vec2 p) {
  return 0.2 * sin(p.x * 2.6 + 1.0) + 0.42 * (noise(p * 1.9 + 3.0) - 0.5) + 0.1 * noise(p * 4.6);
}

// the fiber i, at the distance v from its middle, in fibers
vec4 fiber(vec2 uv, float i, float v, float slope, float env) {
  float s = (i + 0.5) / fibers;
  float h = hash2(vec2(i, 2.0)).x - 0.5;
  // neighbors mostly slide together, so that the fibers stay silky on busy images
  float slide = 0.4 * h + 0.7 * (noise(vec2(i * 0.31, 8.0)) - 0.5);
  float facing = clamp(slope + 0.5 * h + 0.9 * (noise(vec2(s * 6.0, 3.0)) - 0.5), -2.4, 2.4);
  float y = mix(-2.6, 2.6, progress) - facing;
  vec2 off = strength * env * (normalize(vec2(1.0, -slope)) * 0.1 * slide + vec2(0.0, 0.016) * v);
  vec2 q = fold(uv + vec2(0.87758 * off.x + 0.47943 * off.y, 0.87758 * off.y - 0.47943 * off.x) / vec2(ratio, 1.0));
  vec4 a = getFromColor(q), b = getToColor(q);
  a.rgb *= a.a;
  b.rgb *= b.a;
  vec4 c = mix(a, b, smoothstep(-0.14, 0.14, y));
  float silk = 1.0 - 4.0 * v * v;
  // uneven fibers, as regular ones make moire in a small frame
  float uneven = 0.4 + 1.2 * hash2(vec2(i, 5.0)).y;
  c.rgb *= 1.0 + strength * env * (0.55 * exp(-7.0 * y * y) * (0.5 + 0.5 * silk) + 0.26 * uneven * (silk - 0.75));
  return c;
}

vec4 transition(vec2 uv) {
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  p = vec2(0.87758 * p.x - 0.47943 * p.y, 0.47943 * p.x + 0.87758 * p.y);
  float env = smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
  float slope = (bend(p + vec2(0.03, 0.0)) - bend(p - vec2(0.03, 0.0))) / 0.06;
  float k = (p.y + bend(p)) * fibers;
  // fibers of uneven widths
  k += 0.8 * noise(vec2(k * 0.4, 6.0)) - 0.5;
  float i = floor(k), f = k - i;
  vec4 c = mix(fiber(uv, i, min(f, 0.5), slope, env), fiber(uv, i + 1.0, max(f - 1.0, -0.5), slope, env), smoothstep(0.25, 0.75, f));
  return c.a > 0.0 ? vec4(min(c.rgb / c.a, 1.0), c.a) : vec4(0.0);
}
