// Author: gre
// License: MIT
// Description: A warm brown wash is brushed over the outgoing picture until it is a sepia monochrome; under the brush the monochrome turns into the incoming picture, then transparent color glazes are brushed on one hue at a time, warm colors first, then greens, then blues, until it is in full color
// Tags: painting, brush, sepia, monochrome, color, organic

// @range(0, 1) Warmth of the brown underpainting
uniform float warmth; // = 0.7
// @range(0, 1) How visible the brush marks of the washes and glazes are
uniform float brushiness; // = 0.6

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

vec3 umber(float l) {
  vec3 dark = mix(vec3(0.12, 0.11, 0.1), vec3(0.2, 0.1, 0.05), warmth);
  vec3 light = mix(vec3(0.9, 0.89, 0.86), vec3(0.96, 0.86, 0.66), warmth);
  return mix(dark, light, smoothstep(0.0, 1.0, l));
}

// order in which a broad brush reaches each spot of a pass, 0..1, streaked along the brush direction
float brush(vec2 q, float a, float seed) {
  vec2 d = vec2(cos(a), sin(a));
  vec2 r = vec2(dot(q, d), dot(q, vec2(-d.y, d.x)));
  float broad = noise(r * vec2(1.2, 2.5) + seed);
  float streak = noise(r * vec2(3.0, 90.0) + seed * 3.0);
  return clamp(0.15 + 0.7 * broad + brushiness * 0.25 * (streak - 0.5), 0.0, 1.0);
}

float brushPass(float order, float t0, float dur) {
  return smoothstep(0.0, 0.12, (progress - t0) / dur * 1.2 - order);
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec3 lw = vec3(0.299, 0.587, 0.114);
  float la = dot(a.rgb, lw);
  float lb = dot(b.rgb, lw);
  float wash = brushPass(brush(q, 0.5, 1.0), 0.02, 0.3);
  float tone = brushPass(brush(q, -0.4, 7.0), 0.3, 0.28);
  vec3 under = umber(mix(la, lb, tone));
  vec3 hb = b.rgb - lb;
  float warm = max(hb.r - hb.b, 0.0) + 0.5 * max(hb.r - hb.g, 0.0);
  float green = max(hb.g - 0.5 * (hb.r + hb.b), 0.0);
  float cool = max(hb.b - hb.r, 0.0);
  float sum = warm + green + cool + 1e-4;
  float g1 = brushPass(brush(q, 0.9, 13.0), 0.56, 0.22);
  float g2 = brushPass(brush(q, -0.2, 19.0), 0.66, 0.2);
  float g3 = brushPass(brush(q, 0.3, 29.0), 0.76, 0.2);
  float glazed = (warm * g1 + green * g2 + cool * g3) / sum;
  glazed = mix(glazed, g3, smoothstep(0.85, 1.0, progress));
  vec3 col = mix(a.rgb, umber(la), wash);
  col = mix(col, under, tone);
  col = mix(col, b.rgb, glazed);
  return vec4(col, mix(a.a, b.a, tone));
}
