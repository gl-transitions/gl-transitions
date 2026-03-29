// Author: gre
// License: MIT

uniform float intensity; // = 0.3; // if 0.0, the image directly turn grayscale, if 0.9, the grayscale transition phase is very important
uniform bool transparentMode; // = false
 
vec3 grayscale (vec3 color) {
  return vec3(0.2126*color.r + 0.7152*color.g + 0.0722*color.b);
}
 
vec4 transition (vec2 uv) {
  vec4 fc = getFromColor(uv);
  vec4 tc = getToColor(uv);
  float alpha = transparentMode ? (fc.a + tc.a)/2.0 : 1.0;
  return mix(
    mix(vec4(grayscale(fc.rgb), alpha), fc, smoothstep(1.0-intensity, 0.0, progress)),
    mix(vec4(grayscale(tc.rgb), alpha), tc, smoothstep(    intensity, 1.0, progress)),
    progress);
}
