// Author: Thibaut Foussard
// based on Directional transition by Gaëtan Renaudeau
// https://gl-transitions.com/editor/Directional
// License: MIT

#define PI acos(-1.0)

uniform vec2 direction; // = vec2(0.0, -1.0)
uniform float scale; // = .7

float parabola(float x) {
  float y = pow(sin(x * PI), 1.);
  return y;
}

vec4 transition (vec2 uv) {
  float easedProgress = pow(sin(progress  * PI / 2.), 3.);
  vec2 p = uv + easedProgress * sign(direction);
  vec2 f = fract(p);
  
  float s = 1. - (1. - (1. / scale)) * parabola(progress);
  f = (f - 0.5) * s  + 0.5;
  
  vec4 col1 = getToColor(f);
  vec4 col2 = getFromColor(f);
  float mixer = step(0.0, p.y) * step(p.y, 1.0) * step(0.0, p.x) * step(p.x, 1.0);
  vec4 col = mix(col1, col2, mixer);
  
  float limit = .0025;
  float ratio = 1./1.;
  float border = step(limit, f.x * ratio);
  border *= step(limit, (1. - f.x) * ratio);
  border *= step(limit, f.y);
  border *= step(limit, 1. - f.y);
  col *= border;
  return col;
}
