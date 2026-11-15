// Author: Mr Speaker
// License: MIT
// Description: A spinning pinwheel reveals the incoming image
// Tags: pinwheel, radial, rotate

// @param Rotation speed
uniform float speed; // = 2.0

vec4 transition(vec2 uv) {
  
  vec2 p = uv.xy / vec2(1.0).xy;
  
  float circPos = atan(p.y - 0.5, p.x - 0.5) + progress * speed;
  float modPos = mod(circPos, 3.1415 / 4.);
  // starts just below 0 so the sector edges are not drawn on the first frame
  float signed = sign(progress * (3.1415 / 4. + 0.01) - 0.01 - modPos);
  
  return mix(getToColor(p), getFromColor(p), step(signed, 0.5));
  
}
