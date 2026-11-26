// Author: gre
// License: MIT
// Description: The outgoing picture cools down like a glowing filament, its dark parts going out first and its highlights fading last through white, yellow, orange and red, while the incoming picture heats up the opposite way, brightest parts first as red-hot lines, until it reaches its true colors
// Tags: light, glow, heat, luma, color

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// blackbody-like ramp above the threshold th, tinted a little by the pixel's own hue
vec3 glow(vec3 c, float l, float th) {
  float t = clamp((l - th) / (1.0 - min(th, 0.8)), 0.0, 1.0);
  vec3 bb = vec3(smoothstep(0.0, 0.35, t), smoothstep(0.2, 0.75, t), smoothstep(0.5, 1.0, t)) * (0.5 + 0.9 * t * t);
  return bb * mix(vec3(1.0), 0.4 + 0.6 * c / max(l, 0.05), 0.4);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float la = luma(a.rgb), lb = luma(b.rgb);
  // brightest parts are hottest: last to cool, first to light
  float ca = 1.15 * clamp(p / 0.75, 0.0, 1.0);
  float cb = 1.15 * clamp((0.9 - p) / 0.7, 0.0, 1.0);
  vec3 c = mix(a.rgb, glow(a.rgb, la, ca), smoothstep(0.0, 0.18, p)) + glow(b.rgb, lb, cb);
  float s = smoothstep(0.76, 1.0, p);
  return vec4(mix(min(c, 1.0), b.rgb, s), mix(a.a, b.a, smoothstep(0.0, 1.0, p)));
}
