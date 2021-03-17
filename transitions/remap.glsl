// Author: Jeremiah Montoya
// License: MIT

vec4 transition (vec2 uv) {  
  vec4 coord = getToColor(uv);
  return getFromColor(
    vec2(coord.r, coord.g)
  );
}
