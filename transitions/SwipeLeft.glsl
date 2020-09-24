// Author:CheneyChan
// License: MIT

vec4 transition (vec2 uv) {
  if (1.0 - uv.x > progress) {
    return getFromColor(vec2(uv.x + progress, uv.y));
  } else {
    return getToColor(vec2(uv.x + progress - 1.0, uv.y));
  }
}
