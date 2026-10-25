// Author: gre
// License: MIT
// Description: A fade through a solid color, black by default
// Tags: fade, color
// @color Color to fade through
uniform vec4 color; // = vec4(0.0, 0.0, 0.0, 1.0)
// @range(0, 1) How long the color shows in the middle
uniform float colorPhase; // = 0.4 ; // if 0.0, there is no black phase, if 0.9, the black phase is very important
vec4 transition (vec2 uv) {
  return mix(
    mix(color, getFromColor(uv), smoothstep(1.0-colorPhase, 0.0, progress)),
    mix(color, getToColor(uv), smoothstep(    colorPhase, 1.0, progress)),
    progress);
}
