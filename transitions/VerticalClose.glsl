// Author: martiniti
// License: MIT

vec4 transition (vec2 uv) {

  float s = 2.0 - abs((uv.x - 0.5) / (progress - 1.0)) - 2.0 * progress;
  
  return mix(
    getFromColor(uv),
    getToColor(uv),
    smoothstep(0.5, 0.0, s)
  );
}
