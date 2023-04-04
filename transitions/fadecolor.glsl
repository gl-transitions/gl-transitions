// author: gre
// License: MIT
uniform vec3 color;// = vec3(0.0)
uniform float colorPhase/* = 0.4 */; // if 0.0, there is no black phase, if 0.9, the black phase is very important
uniform bool usebgcolor; // = false
uniform vec4 bgcolor; // = vec4(0.0, 0.0, 0.0, 1.0)
vec4 mixColor = usebgcolor ? bgcolor : vec4(color, 1.0);
vec4 transition (vec2 uv) {
  return mix(
    mix(mixColor, getFromColor(uv), smoothstep(1.0-colorPhase, 0.0, progress)),
    mix(mixColor, getToColor(uv), smoothstep(    colorPhase, 1.0, progress)),
    progress);
}
