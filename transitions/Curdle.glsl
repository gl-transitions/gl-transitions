// Author: gre
// License: MIT
// Description: The outgoing picture curdles: it separates into soft lumps with pale, milky whey opening between them onto the incoming picture, and each lump's content squeezes in toward its own middle as the lumps shrink away, until only the incoming picture remains
// Tags: organic, liquid, noise, dissolve, distort

// @range(1, 10) Number of lumps across the frame height
uniform float size; // = 4.0
// @color Milky tint of the whey over the incoming picture when it first opens (its alpha is its strength)
uniform vec4 whey; // = vec4(0.97, 0.95, 0.85, 0.35)

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x),
    f.y
  );
}

float field(vec2 p) {
  return 0.85 * noise(p) + 0.15 * noise(p * 2.7 + 5.2);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 p = vec2(uv.x * ratio, uv.y) * size;
  float n = field(p);
  vec2 e = vec2(0.02, 0.0);
  vec2 g = vec2(field(p + e.xy) - n, field(p + e.yx) - n) / e.x;
  float x = 2.0 * t - 1.0;
  // cubic in the middle so the lumps keep shrinking through the whole transition
  float th = 0.5 + 0.58 * (0.35 * x + 0.65 * x * x * x);
  float curd = smoothstep(th - 0.02, th + 0.02, n);
  // the lump's content is squeezed uphill toward its peak as it shrinks
  vec2 q = uv - g / size * vec2(1.0 / ratio, 1.0) * 0.1 * smoothstep(0.0, 1.0, t) * (1.0 + 3.0 * max(0.0, th - 0.3));
  vec4 a = getFromColor(q);
  a.rgb *= 1.0 + 0.25 * t * (1.0 - smoothstep(th + 0.01, th + 0.12, n));
  vec4 b = getToColor(uv);
  b.rgb = mix(b.rgb, whey.rgb, whey.a * (1.0 - t) * (1.0 - t));
  return mix(b, clamp(a, 0.0, 1.0), curd);
}
