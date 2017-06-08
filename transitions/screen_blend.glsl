// Author: Fernando Kuteken
// License: MIT

vec4 blend(vec4 a, vec4 b) {
  return 1.0 - (1.0 - a) * (1.0 - b);
}

vec4 transition (vec2 uv) {
  
  vec4 blended = blend(getFromColor(uv), getToColor(uv));
  
  if (progress < 0.5)
    return mix(getFromColor(uv), blended, 2.0 * progress);
  else
    return mix(blended, getToColor(uv), 2.0 * progress - 1.0);
}
