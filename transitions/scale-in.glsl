// Author:1
// License: MIT

vec4 scale(in vec2 uv, in vec2 scale){
    vec2 s = mix(vec2(1.0), scale, progress) - vec2(1.0);
    uv = 0.5 + (uv - 0.5) * s;
    return getToColor(uv);
}

vec4 transition (vec2 uv) {
  return mix(
    getFromColor(uv),
    scale(uv, vec2(2.0)),
    progress
  );
}
