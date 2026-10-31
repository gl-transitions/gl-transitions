// Author: gre
// License: MIT
// Description: A spiral arm winds out from the center and widens to reveal the incoming image
// Tags: shape, wipe, radial

#define PI 3.141592653589793

// @range(2, 8) Number of turns of the spiral
uniform float turns; // = 3.0
// @range(0, 0.5) Softness of the arm's edges
uniform float smoothness; // = 0.05
// @param Wind clockwise; false winds counterclockwise
uniform bool clockwise; // = true

// Coverage of the arm turn at position s (in turns along the spiral), d away from its middle line
float arm (float s, float d) {
  // The tip reaches the frame's corners at 60% of the transition, and the whole arm widens until the end
  float end = -0.5 + (turns + 0.5) / 0.6;
  float tip = mix(-0.5, end, progress);
  s = max(s, -0.5);
  float width = sqrt(clamp((tip - s) / max(end - s, 0.001), 0.0, 1.0));
  // Edge softness in arm widths, at least a pixel wide
  float e = smoothness + 0.005 * turns;
  return smoothstep(0.0, e, width * (0.5 + e) - d);
}

vec4 transition (vec2 uv) {
  // Square pixels, normalized so the frame's corners are at distance 1
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0) / (0.5 * length(vec2(ratio, 1.0)));
  // Fraction of a turn, starting at the top
  float a = dot(q, q) < 1e-12 ? 0.0 : atan(q.x, q.y) / (2.0 * PI);
  a = fract(clockwise ? a : -a);
  // Radius in turns of the spiral, and the arm turn the point is in
  float w = length(q) * turns - a;
  float n = floor(w);
  float f = w - n;
  // The arm turns around it can overlap it near the edges
  float m = max(arm(n + a, abs(f - 0.5)), max(arm(n + 1.0 + a, 1.5 - f), arm(n - 1.0 + a, f + 0.5)));
  return mix(getFromColor(uv), getToColor(uv), m);
}
