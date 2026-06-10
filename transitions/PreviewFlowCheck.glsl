// Author: gre
// License: MIT

vec4 transition (vec2 uv) {
  return mix(
    getToColor(uv),
    getFromColor(uv),
    step(progress, uv.x)
  );
}
