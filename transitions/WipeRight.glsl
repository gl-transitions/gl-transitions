// Author: Jake Nelson
// License: MIT
// Description: A hard-edged wipe from left to right
// Tags: wipe, horizontal

vec4 transition(vec2 uv) {
  vec2 p=uv.xy/vec2(1.0).xy;
  vec4 a=getFromColor(p);
  vec4 b=getToColor(p);
  return mix(a, b, step(0.0+p.x,progress));
}
