// Author: gre
// License: MIT
// Description: A soft-edged diamond grows from the center to reveal the incoming image
// Tags: shape, wipe, iris

// @param Center of the diamond
uniform vec2 center; // = vec2(0.5)
// @range(0, 0.5) Softness of the diamond's edge
uniform float smoothness; // = 0.03

vec4 transition (vec2 uv) {
  // Measured in square pixels, so the diamond is not stretched
  vec2 d = abs(uv - center) * vec2(ratio, 1.0);
  // The diamond covers the frame once it reaches the farthest corner
  vec2 far = max(center, 1.0 - center) * vec2(ratio, 1.0);
  float dist = (d.x + d.y) / (far.x + far.y);
  float s = max(smoothness, 0.001);
  float m = smoothstep(0.0, s, progress * (1.0 + s) - dist);
  return mix(getFromColor(uv), getToColor(uv), m);
}
