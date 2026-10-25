// Author: nwoeanhinnogaehr
// License: MIT
// Description: A crossfade through the HSV color space that cycles through hues
// Tags: fade, color, hue
// Ported from https://gist.github.com/nwoeanhinnogaehr/b185145363d65751009b

// HSV functions from http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl

vec3 hsv2rgb(vec3 c) {
  const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c) {
  const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.001)), d / (q.x + 0.001), q.x);
}

vec4 transition(vec2 uv) {
  vec3 a = rgb2hsv(getFromColor(uv).rgb);
  vec3 b = rgb2hsv(getToColor(uv).rgb);
  vec3 m = mix(a, b, progress);
  return vec4(hsv2rgb(m), 1.0);
}
