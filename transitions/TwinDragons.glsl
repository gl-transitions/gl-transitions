// Author: gre
// License: MIT
// Description: The grains of the outgoing image join in pairs, and the pairs in pairs, each time growing into a bigger dragon-shaped patch of flat color with the same ragged outline at every size, until a few huge interlocked dragons fill the frame; they are repainted along their own curl and split back down into the incoming image
// Tags: fractal, dragon, blocks, flat-color, math
// Preview: 0.5

// @range(40, 200) Grains along the height of the frame
uniform float cells; // = 120.0
// @range(0, 1) How vivid the flat colors are
uniform float vividness; // = 0.6

vec4 vivid(vec4 c, float k) {
  float g = dot(c.rgb, vec3(0.333));
  return vec4(clamp(g + (c.rgb - g) * (1.0 + vividness * k), 0.0, 1.0), c.a);
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 dragon(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  vec2 z = floor((uv - 0.5) * a * cells);
  float u = min(progress, 1.0 - progress);
  // the digits of z in base 1 + i, whose powers are in pw
  vec2 pw = vec2(1.0, 0.0);
  vec2 mid = vec2(0.5);
  vec2 q = uv;
  float low = 0.0;
  float size = 1.0;
  for (int l = 0; l < 11; l++) {
    float d = mod(z.x + z.y, 2.0);
    z = vec2(z.x - d + z.y, z.y - z.x + d) * 0.5;
    low += d * size;
    size *= 2.0;
    mid += 0.5 * pw;
    pw = vec2(pw.x - pw.y, pw.x + pw.y);
    vec2 base = vec2(z.x * pw.x - z.y * pw.y, z.x * pw.y + z.y * pw.x);
    if (u > 0.014 + 0.034 * float(l) + (0.03 + 0.006 * float(l)) * low / size) q = fold((base + mid) / cells / a + 0.5);
  }
  bool late = progress > 0.44 + 0.12 * (low + 0.5) / size;
  vec4 c = vivid(late ? getToColor(q) : getFromColor(q), smoothstep(0.0, 0.35, u));
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  vec2 e = 0.0011 / vec2(ratio, 1.0) * smoothstep(0.0, 0.1, min(progress, 1.0 - progress));
  vec4 s = dragon(uv + e * vec2(0.5, 1.0)) + dragon(uv + e * vec2(-1.0, 0.5)) + dragon(uv - e * vec2(0.5, 1.0)) + dragon(uv - e * vec2(-1.0, 0.5));
  return vec4(s.rgb / max(s.a, 1e-5), 0.25 * s.a);
}
