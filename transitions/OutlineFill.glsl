// Author: gre
// License: MIT
// Description: The incoming image is colored in from its own outlines: they appear first as thin lines over the outgoing image, then its colors spread out from every outline with a soft, darker wet edge, and the widest plain areas fill in last
// Tags: edges, reveal, organic, paint

// @range(0.05, 0.5) How far the color spreads from the outlines, in frame heights: areas farther from any outline fill in at the end
uniform float reach; // = 0.25
// @range(0, 1) Contrast needed around a pixel before the color reaches it: lower also spreads from faint edges
uniform float threshold; // = 0.4

const int TAPS = 30;

float luma(vec4 c) {
  return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a + 0.3 * (1.0 - c.a);
}

float hash(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float vnoise(vec2 v) {
  vec2 i = floor(v);
  vec2 f = fract(v);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 fold(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  vec4 b = getToColor(uv);
  float l0 = luma(b);
  float th = mix(0.02, 0.24, clamp(threshold, 0.0, 1.0));
  float e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
  float front = mix(-0.1, 1.12, e);
  float m = smoothstep(0.88, 1.12, front);
  float wet = smoothstep(0.88, 1.12, front - 0.12);
  float diff = 0.0;
  float spin = 3.1416 * vnoise(uv * vec2(ratio, 1.0) * 6.0);
  vec2 dir = vec2(cos(spin), sin(spin));
  // golden angle rotation, so the taps make a spiral without per-tap trig
  mat2 turn = mat2(-0.73736, 0.67549, -0.67549, -0.73736);
  for (int i = 0; i < TAPS; i++) {
    float f = (float(i) + 0.5) / float(TAPS);
    float r = 0.01 + 0.99 * f * sqrt(f);
    float l = luma(getToColor(fold(uv + reach * r * vec2(dir.x / ratio, dir.y))));
    dir = turn * dir;
    diff = mix(diff, abs(l - l0), 0.2);
    float hit = smoothstep(th * 0.3, th, diff);
    m = max(m, hit * smoothstep(r - 0.1, r + 0.1, front));
    wet = max(wet, hit * smoothstep(r - 0.1, r + 0.1, front - 0.12));
  }
  float rim = max(m - wet, 0.0) * (1.0 - smoothstep(0.8, 1.0, progress));
  b.rgb *= 1.0 - 0.25 * rim;
  return mix(getFromColor(uv), b, m);
}
