// Author: gre
// License: MIT
// Description: An orbital sander wanders over the outgoing picture as if it were a painted board: the paint scuffs and dulls under the pad, then wears through to a ring of primer with the incoming picture underneath, and the worn patches spread and join until the whole board is sanded back
// Tags: wood, craft, texture, organic, reveal

// @range(0.05, 0.4) Size of the sanding pad, in frame heights
uniform float pad; // = 0.17
// @range(0, 10, 1) Changes the sander's path and the paint's grain
uniform float seed; // = 1.0
// @color Color of the primer ring and of the sanding dust
uniform vec4 primer; // = vec4(0.93, 0.91, 0.86, 1.0)

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  vec4 h = fract(vec4(i.x + i.y * 57.0, i.x + 1.0 + i.y * 57.0, i.x + (i.y + 1.0) * 57.0, i.x + 1.0 + (i.y + 1.0) * 57.0) * 0.1031 + seed * 0.37);
  h = fract(h * (h + 33.33) * 4.17);
  return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

vec2 path(float s) {
  return vec2((0.5 + 0.42 * sin(6.2832 * (1.25 * s + 0.07 * seed) - 1.2)) * ratio, 0.5 + 0.38 * sin(6.2832 * (2.1 * s + 0.11 * seed) + 0.4));
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 p = vec2(uv.x * ratio, uv.y);
  float wear = 0.0;
  float dust = 0.0;
  for (int i = 0; i < 14; i++) {
    float s = float(i) / 13.0;
    vec2 c = path(s);
    float w = clamp((t * 1.15 - s * 0.8) / 0.24, 0.0, 1.0);
    float d2 = dot(p - c, p - c) / (pad * pad);
    wear += 1.6 * w * w * exp(-d2);
    dust += w * (1.0 - w) * 4.0 * exp(-d2 * 0.5);
  }
  float paint = 0.85 + 0.3 * noise(p * 9.0) + 0.1 * noise(p * 31.0);
  // above the deepest paint plus the bare threshold, so the board ends fully sanded
  wear += 1.6 * smoothstep(0.6, 1.0, t);
  float aa = 0.04;
  float primed = smoothstep(paint - aa, paint + aa, wear);
  float bare = smoothstep(paint + 0.22, paint + 0.22 + aa * 1.5, wear);
  vec4 a = getFromColor(uv);
  float scuff = smoothstep(0.0, paint, wear) * (1.0 - primed);
  float scratch = 0.5 + 0.5 * sin(dot(p, vec2(0.8, 0.6)) * 900.0 + noise(p * 40.0) * 20.0);
  a.rgb = mix(a.rgb, vec3(dot(a.rgb, vec3(0.3, 0.59, 0.11))) * 0.85 + 0.25, 0.45 * scuff);
  a.rgb += 0.06 * scuff * scratch;
  vec4 c = mix(a, vec4(primer.rgb * (0.92 + 0.08 * noise(p * 60.0)), primer.a), primed);
  c = mix(c, getToColor(uv), bare);
  c.rgb = mix(c.rgb, primer.rgb, 0.35 * clamp(dust, 0.0, 1.0) * (1.0 - smoothstep(0.75, 1.0, t)));
  return c;
}
