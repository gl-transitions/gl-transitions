// author: gre
// license: MIT

vec4 transition (vec2 uv) {
  return smoothstep(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
