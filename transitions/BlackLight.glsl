// Author: gre
// License: MIT
// Description: The house lights go out and ultraviolet comes on: the outgoing picture's whites glow lavender and its saturated colors turn neon with a soft halo over a deep violet dark; the incoming picture's most fluorescent parts light up first, the rest follows, then white light comes back on it
// Tags: light, neon, glow, ultraviolet, color, stage

// @range(0, 2) Glow around the fluorescent colors
uniform float glow; // = 1.0

vec3 fluorescence(vec3 c) {
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  float s = mx - mn;
  vec3 hue = (c - mn) / (s + 1e-3);
  vec3 neon = hue * hue * s * smoothstep(0.1, 0.7, s) * mx * 1.6;
  // optical brighteners make whites glow lavender
  vec3 white = vec3(0.62, 0.5, 1.0) * smoothstep(0.55, 0.95, mn);
  return vec3(0.07, 0.02, 0.14) * (0.3 + mx) + neon + white;
}

vec3 halo(vec2 uv, bool incoming, vec2 asp) {
  vec3 s = vec3(0.0);
  for (int i = 0; i < 6; i++) {
    float an = 1.047 * float(i) + 0.5;
    vec2 o = vec2(cos(an), sin(an)) * 0.022 * asp;
    vec4 c = incoming ? getToColor(uv + o) : getFromColor(uv + o);
    s += fluorescence(c.rgb);
  }
  return s / 6.0;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(1.0 / ratio, 1.0);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float k = smoothstep(0.05, 0.3, p) * (1.0 - smoothstep(0.7, 0.95, p));
  vec3 ua = fluorescence(a.rgb);
  vec3 ub = fluorescence(b.rgb);
  float gb = dot(ub, vec3(0.33));
  // the incoming picture's most fluorescent parts light up first
  float s = clamp((p - 0.32) * 4.0 + (gb - 0.3) * 1.5, 0.0, 1.0);
  s = mix(s, smoothstep(0.35, 0.65, p), 1.0 - k);
  vec3 h = mix(halo(uv, false, asp), halo(uv, true, asp), s);
  vec3 dark = mix(ua, ub, s) + glow * 0.5 * h;
  vec3 day = mix(a.rgb, b.rgb, s);
  return vec4(min(mix(day, dark, k), vec3(1.0)), mix(a.a, b.a, s));
}
