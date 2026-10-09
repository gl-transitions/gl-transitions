// Author: lizhongjian
// License: MIT
// Description: Both images slide sideways while crossfading
// Tags: slide, horizontal, blend

vec4 transition (vec2 uv) {
  vec2 newUV = uv;
  newUV.x -= progress;
  if(uv.x >= progress)
  {
    return getFromColor(newUV);
  }

  
  return mix(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
