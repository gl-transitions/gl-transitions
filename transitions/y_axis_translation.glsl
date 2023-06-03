// Author:lizhongjian
// License: MIT

vec4 transition (vec2 uv) {
  vec2 newUV = uv;
  newUV.y += progress;
  if(uv.y >= progress)
  {
    return getFromColor(newUV);
  }

  
  return mix(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
