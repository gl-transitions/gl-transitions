// Author:a
// License: MIT

vec4 transition (vec2 uv) {
  
  vec2 p = uv + 0.01 * vec2(sin(300.0 * uv.x * progress), cos(300.0 * uv.y * progress));
  
  return mix(
    getFromColor(p),
    getToColor(uv),
    progress
  );
  
}
