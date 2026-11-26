// Author: gre
// License: MIT
// Description: The picture turns into a red and cyan 3D anaglyph whose two copies pull apart, more at the bottom of the frame; the cyan eye sees the incoming picture first while the red eye still holds the outgoing one, then the red eye catches up, the copies close together and color returns
// Tags: 3d, color, split, stereo, retro

// @range(0, 0.08) Eye separation at the peak, in frame heights
uniform float depth; // = 0.035

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec4 transition(vec2 uv) {
  float p = progress;
  float look = smoothstep(0.0, 0.28, p) * (1.0 - smoothstep(0.72, 1.0, p));
  // nearer at the bottom of the frame, like ground running away from the viewer
  float d = depth * look * (1.35 - 0.9 * uv.y) / ratio;
  vec2 l = 1.0 - abs(1.0 - abs(uv + vec2(d, 0.0)));
  vec2 r = 1.0 - abs(1.0 - abs(uv - vec2(d, 0.0)));
  // the right (cyan) eye sees the incoming picture first; the left (red) eye follows
  float sl = smoothstep(0.42, 0.68, p);
  float sr = smoothstep(0.3, 0.56, p);
  vec4 L = mix(getFromColor(l), getToColor(l), sl);
  vec4 R = mix(getFromColor(r), getToColor(r), sr);
  float red = mix(L.r, 1.1 * luma(L.rgb), 0.9 * look);
  vec3 cyan = mix(R.rgb, vec3(luma(R.rgb)) * vec3(0.0, 1.0, 1.05), 0.85 * look);
  return vec4(red, cyan.g, cyan.b, mix(L.a, R.a, 0.5));
}
