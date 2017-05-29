// Author: Fernando Kuteken
// License: MIT

#define PI 3.141592653589

vec4 transition (vec2 uv) {

  float angle = atan(uv.y - 0.5, uv.x - 0.5);
  float normalizedAngle = (angle + PI) / (2.0 * PI);
  
  if (normalizedAngle > progress)
    return getFromColor(uv);
  else
    return getToColor(uv);
}
