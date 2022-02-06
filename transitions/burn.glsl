// author: gre
// License: MIT
uniform vec3 color /* = vec3(0.1, 0.8, 0.6) */;
vec4 transition (vec2 uv) {
  return mix(
    getFromColor(uv) + vec4(progress*color, 1.0),
    getToColor(uv) + vec4((1.0-progress)*color, 1.0),
    progress
  );
}
