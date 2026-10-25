// Author: gre
// License: MIT
// Description: The incoming image appears through vertical slices that widen
// Tags: slices, stripes, wipe

// @param Number of slices
uniform float count; // = 10.0
// @param Softness of the slices' edges
uniform float smoothness; // = 0.5

vec4 transition (vec2 p) {
  float pr = smoothstep(-smoothness, 0.0, p.x - progress * (1.0 + smoothness));
  float s = step(pr, fract(count * p.x));
  return mix(getFromColor(p), getToColor(p), s);
}
