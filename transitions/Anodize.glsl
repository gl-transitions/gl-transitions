// Author: gre
// License: MIT
// Description: The outgoing picture is anodized like titanium: as the voltage climbs, interference colors run over it through bronze, purple, blue, gold, pink and green, its bright and dark parts a step apart so its shapes stay readable, and under the running colors it becomes the incoming picture, which loses the oxide and gets its own colors back
// Tags: color, metal, light, rainbow, dissolve

// @range(0.5, 2) Highest voltage: how far the oxide colors run through bronze, purple, blue, gold, pink and green
uniform float voltage; // = 1.2
// @range(0, 1) How much the picture's own brightness thickens the oxide, so its shapes stay readable in the colors
uniform float relief; // = 0.6

vec3 anFilm(float d) {
  // two-beam interference of an oxide layer; d in optical micrometres
  vec3 c = 0.5 + 0.5 * cos(6.2832 * 2.0 * d / vec3(0.62, 0.54, 0.46) + 3.1416);
  return mix(vec3(0.62, 0.6, 0.57), c, smoothstep(0.0, 0.12, d));
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float p = progress;
  vec3 lw = vec3(0.299, 0.587, 0.114);
  float la = dot(a.rgb, lw), lb = dot(b.rgb, lw);
  float sw = smoothstep(0.35, 0.65, p);
  float l = mix(la, lb, sw);
  float env = sin(3.14159 * p);
  env = smoothstep(0.0, 1.0, min(env * 1.6, 1.0));
  // the oxide only grows: the swap of pictures shows as the colors flowing on
  float d = voltage * 0.45 * p + relief * 0.32 * l * env;
  vec3 metal = mix(anFilm(d), vec3(1.0), 0.15) * (0.55 + 0.6 * l) + 0.1 * l * l;
  vec3 base = mix(a.rgb, b.rgb, sw);
  vec3 col = mix(base, metal, env);
  return vec4(clamp(col, 0.0, 1.0), mix(a.a, b.a, sw));
}
