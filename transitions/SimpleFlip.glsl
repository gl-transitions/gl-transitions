// Author: nwoeanhinnogaehr
// License: MIT
// Description: The outgoing image flips around the vertical axis into the incoming one
// Tags: flip, horizontal
// Ported from https://gist.github.com/nwoeanhinnogaehr/408045772d255df97520

vec4 transition(vec2 uv) {
  vec2 q = uv;
  uv.x = (uv.x - 0.5) / abs(progress - 0.5) * 0.5 + 0.5;
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  return vec4(mix(a, b, step(0.5, progress)).rgb * step(abs(q.x - 0.5), abs(progress - 0.5)), 1.0);
}
