// Author: hong
// License: MIT

vec2 skewRight(vec2 p) {
  float skewX = (p.x - progress)/(0.5 - progress) * 0.5;
  float skewY =  (p.y - 0.5)/(0.5 + progress * (p.x - 0.5) / 0.5)* 0.5  + 0.5;
  return vec2(skewX, skewY);
}

vec2 skewLeft(vec2 p) {
  float skewX = (p.x - 0.5)/(progress - 0.5) * 0.5 + 0.5;
  float skewY = (p.y - 0.5) / (0.5 + (1.0 - progress ) * (0.5 - p.x) / 0.5) * 0.5  + 0.5;
  return vec2(skewX, skewY);
}

vec4 addShade() {
  float shadeVal  =  max(0.7, abs(progress - 0.5) * 2.0);
  return vec4(vec3(shadeVal ), 1.0);
}

vec4 transition (vec2 p) {
  float pr = step(1.0 - progress, p.x);

  if (p.x < 0.5) {
    return mix(getFromColor(p), getToColor(skewLeft(p)) * addShade(), pr);
  } else {
    return mix(getFromColor(skewRight(p)) * addShade(), getToColor(p),   pr);
  }
}
