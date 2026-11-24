// Author: gre
// License: MIT
// Description: The outgoing picture rounds into a paper lantern lit warmly from inside and drifts off into the dusk over the incoming picture, while little lanterns made of the same picture rise on both sides; as the last ones float away, day breaks on the incoming picture
// Tags: lantern, night, light, rise, poetic

// @range(0, 1) How dark the dusk gets
uniform float dusk; // = 0.85
// @range(0, 1) Strength of the glow
uniform float glow; // = 0.8
// @color Light of the flame
uniform vec3 flame; // = vec3(1.0, 0.66, 0.28)

const int COUNT = 18;

float hash(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

// half width of a lantern of half height 1, down to the round mouth
float profile(float y, float lip) {
  float v = clamp(y, -1.0, 1.0);
  float t = max(v, 0.0);
  float b = max(-v, 0.0);
  float w = 0.72 * sqrt(max(1.0 - t * t * t * t, 0.0)) * (1.0 - 0.3 * b * b);
  float m = max(lip - 1.0 - v, 0.0) / lip;
  return w * sqrt(max(1.0 - m * m, 0.0));
}

// slope of the outline, to keep its feather even on the caps
float steep(float y, float lip) {
  float g = (profile(y + 0.01, lip) - profile(y - 0.01, lip)) * 50.0;
  return sqrt(1.0 + g * g);
}

// l in half heights; k = 0 is the flat picture, 1 the lit lantern; premultiplied
vec4 paper(vec2 l, float w, float k, float lip, float flick) {
  float mouth = mix(ratio, profile(lip - 1.0, lip), k);
  // under the rim w follows the mouth, but the paper keeps its width
  float x = clamp(l.x / max(l.y < lip - 1.0 ? mouth : w, 1e-4), -1.0, 1.0);
  float turn = asin(x * 0.999);
  float bx = mix(x, turn * 0.6366, k);
  vec2 crop = mix(vec2(1.0), min(vec2(0.8 / ratio, ratio / 0.8), 1.0), k);
  vec4 c = getFromColor(clamp(0.5 + 0.5 * vec2(bx, l.y) * crop, 0.0, 1.0));
  vec2 f = (l + vec2(0.0, 0.7)) * vec2(1.25, 0.72);
  float core = exp(-dot(f, f)) * flick;
  vec3 lit = (c.rgb * 0.75 + 0.2 * flame) * mix(vec3(0.7, 0.58, 0.56), 0.55 + 1.3 * flame, core);
  lit += flame * 0.3 * core * core;
  lit *= 1.0 - 0.45 * x * x * x * x;
  lit *= 1.0 - 0.13 * smoothstep(0.88, 1.0, cos(l.y * 20.0));
  lit *= 1.0 - 0.07 * smoothstep(0.92, 1.0, cos(turn * 9.0));
  vec2 e = vec2(l.x / mouth, (l.y + 1.0 - lip) / lip);
  float r = length(e);
  float inside = 1.0 - smoothstep(0.82, 0.92, r);
  vec3 hole = flame * (0.45 + 0.95 * exp(-dot(e, e) * 2.5)) * flick;
  lit = mix(lit, flame * vec3(0.45, 0.36, 0.3), 1.0 - smoothstep(0.98, 1.06, r));
  lit = mix(lit, hole, inside);
  return vec4(mix(c.rgb, lit, k) * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float side = min(ratio, 1.0);

  float night = smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.66, 1.0, p));
  vec4 c = getToColor(uv);
  float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  vec3 moon = mix(vec3(lum), c.rgb, 0.6) * vec3(0.32, 0.42, 0.78) + vec3(0.02, 0.03, 0.08);
  c.rgb = mix(c.rgb, moon, dusk * night) * c.a;

  vec3 halo = vec3(0.0);
  // far to near, so the nearer lanterns overlap
  for (int i = 0; i < COUNT; i++) {
    float f = float(i);
    float z = 0.2 + 0.8 * f / float(COUNT - 1);
    float sz = mix(0.028, 0.115, z * z) * mix(side, 1.0, 0.15);
    float t = p - 0.17 - 0.2 * hash(f + 3.0);
    if (t <= 0.0) continue;
    // the bigger ones keep to the sides, off the subject
    float v = fract(f * 0.618034 + 0.2) * 2.0 - 1.0;
    float x = 0.5 * (ratio + 0.06) * sign(v) * mix(abs(v), 0.5 + 0.5 * abs(v), smoothstep(0.25, 0.5, z));
    x += 0.025 * side * sin(p * 8.0 + f * 2.1);
    float y = -0.5 - 1.3 * sz + t * (1.5 + 1.4 * z) + 0.7 * t * t;
    vec2 d = q - vec2(x, y);
    float sw = 0.1 * sin(p * 9.0 + f * 1.7);
    d = vec2(d.x + sw * d.y, d.y - sw * d.x) / sz;
    float on = smoothstep(0.0, 0.06, t);
    float flick = 0.92 + 0.08 * sin(p * 60.0 + f * 4.0);
    halo += on * flame * (0.3 * exp(-dot(d, d) * 0.55) + 0.06 * exp(-length(d) * 0.7)) * flick;
    if (abs(d.x) < 0.8 && abs(d.y) < 1.0) {
      float w = profile(d.y, 0.09);
      float m = smoothstep(0.0, 0.003 / sz * steep(d.y, 0.09), w - abs(d.x));
      vec4 s = paper(d, w, 1.0, 0.09, flick);
      s.rgb = mix(s.rgb, (0.75 * s.rgb * vec3(0.8, 0.85, 1.0) + vec3(0.03, 0.03, 0.06) * s.a), 1.0 - z);
      c = s * m + c * (1.0 - s.a * m);
    }
  }

  float k = smoothstep(0.01, 0.3, p);
  float up = smoothstep(0.2, 0.92, p);
  float S = mix(0.5, 0.15 * side, smoothstep(0.0, 0.6, p));
  float lip = max(0.09 * k, 1e-3);
  vec2 pos = vec2(0.26 * ratio * smoothstep(0.08, 0.55, p) + 0.03 * side * sin(p * 8.0) * k, 1.0 * up * up + 0.1 * up - 0.03 * k * (1.0 - up));
  vec2 d = q - pos;
  float sw = 0.08 * sin(p * 9.0) * k;
  d = vec2(d.x + sw * d.y, d.y - sw * d.x) / S;
  float flick = 0.94 + 0.06 * sin(p * 50.0);
  float w = mix(ratio, profile(d.y, lip), k);
  // a hair wider than the frame while still flat
  float slack = 0.004 / S * (1.0 - k) + 0.03 * (1.0 - smoothstep(0.0, 0.05, p));
  float m = smoothstep(0.0, 0.004 / S * mix(1.0, steep(d.y, lip), k), w + slack - abs(d.x)) * smoothstep(0.0, 0.004 / S, 1.0 + slack - abs(d.y));
  halo += k * flame * (0.5 * exp(-dot(d, d) * 0.5) + 0.12 * exp(-length(d) * 0.6)) * flick;
  c.rgb += glow * night * 0.55 * halo * (0.35 * c.a + c.rgb);
  vec4 s = paper(d, w, k, lip, flick);
  // the flat picture replaces the incoming one, the lantern floats over it
  c = s * m + c * (1.0 - m * mix(1.0, s.a, k));
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
