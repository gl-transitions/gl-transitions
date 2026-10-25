// Author: haiyoucuv
// License: MIT
// Description: The incoming image scales in from the center while fading in
// Tags: zoom, fade

vec4 scale(in vec2 uv){
    uv = 0.5 + (uv - 0.5) * progress;
    return getToColor(uv);
}

vec4 transition (vec2 uv) {
  return mix(
    getFromColor(uv),
    scale(uv),
    progress
  );
}
