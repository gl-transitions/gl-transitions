// author: gre
// License: MIT
uniform vec3 color /* = vec3(0.9, 0.4, 0.2) */;
uniform bool transparentMode; // = false
vec4 transition (vec2 uv) {
  return mix(
    getFromColor(uv) + vec4(progress*color, transparentMode ? 0.0 : 1.0),
    getToColor(uv) + vec4((1.0-progress)*color, transparentMode ? 0.0 : 1.0),
    progress
  );
}
