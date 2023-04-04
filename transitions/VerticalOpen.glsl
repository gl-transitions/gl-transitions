// Author: martiniti
// License: MIT

vec4 transition (vec2 uv) {

  float regress = 1.0 - progress;
  float s = 2.0 - abs((uv.x - 0.5) / (regress - 1.0)) - 2.0 * regress;
  
  return mix(
    getFromColor(uv),
    getToColor(uv),
    smoothstep(0.0, 0.5, s)
  );
}
