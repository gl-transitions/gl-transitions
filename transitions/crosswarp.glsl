// Author: Eke Péter <peterekepeter@gmail.com>
// License: MIT
vec4 transition(vec2 uv) {
  float x = progress;
  vec2 p = uv.xy / vec2(1.0).xy;
  x=smoothstep(.0,1.0,(x*2.0+p.x-1.0));
  return mix(getFromColor((p-.5)*(1.-x)+.5), getToColor((p-.5)*x+.5), x);
}
