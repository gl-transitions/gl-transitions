// Author: Yoni Maltsman @friendlyspinach
// License: MIT

uniform float r_strength; // = 1.0
uniform float g_strength; // = 1.0
uniform float b_strength; // = 1.0

vec4 transition (vec2 uv) {
  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);
  from.r = mod(from.r + r_strength*progress, 1.0);
  from.g = mod(from.g + g_strength*progress, 1.0);
  from.b = mod(from.b + b_strength*progress, 1.0);
  return mix(from, to, progress);
}
