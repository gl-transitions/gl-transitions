// Author: gre
// License: MIT
// Description: The picture takes on a cross-processed look with punchy reds and yellows and lifted blue shadows while its three dye layers develop the incoming picture out of step, red from the highlights down, blue from the shadows up and green from the midtones, before the curves relax
// Tags: color, film, retro, luma, dissolve

// @range(0, 1) Strength of the cross-processed curves at the peak
uniform float strength; // = 1.0

vec3 curves(vec3 c, float k) {
  // slide film in negative chemistry: hard red and green, flattened blue lifted from the floor
  vec3 s = c * c * (3.0 - 2.0 * c);
  vec3 x = vec3(mix(c.r, s.r * 1.08, k), mix(c.g, s.g * 1.05 + 0.02, k), mix(c.b, 0.22 + 0.55 * c.b, k));
  return clamp(x, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float look = strength * smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.78, 1.0, p));
  // each dye layer develops out of step: red from its highlights down, blue from its shadows up, green in the middle
  vec3 tone = 0.5 * (a.rgb + b.rgb);
  vec3 order = clamp((vec3(1.0 - tone.r, 0.5 + 0.5 * abs(tone.g - 0.5), tone.b) - 0.5) * 1.8 + 0.5, 0.0, 1.0);
  vec3 t = vec3(p) * 2.6 - 0.25 - 1.4 * order;
  vec3 w = smoothstep(0.0, 0.3, t + 0.15 * (vec3(0.0, 0.5, 1.0) - 0.5));
  vec3 c = mix(a.rgb, b.rgb, w);
  return vec4(curves(c, look), mix(a.a, b.a, w.g));
}
