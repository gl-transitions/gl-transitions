// Author: haiyoucuv
// License: MIT

vec4 transition (vec2 uv) {
  
  vec4 coordTo = getToColor(uv);
  vec4 coordFrom = getFromColor(uv);
  
  return mix(
    getFromColor(coordTo.rg),
    getToColor(uv),
    progress
  );

}
