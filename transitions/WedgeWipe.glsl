// Author: gre
// License: MIT
// Description: Two hands sweep away from each other around the center, opening a widening wedge that reveals the incoming image
// Tags: wipe, radial, clock, wedge

#define PI 3.141592653589793

// @range(-180, 180) Direction the wedge opens from, in degrees clockwise from 12 o'clock
uniform float angle; // = 0.0
// @range(0, 0.2) Softness of the hands' edges
uniform float smoothness; // = 0.01
// @param Point the hands turn around
uniform vec2 center; // = vec2(0.5)

vec4 transition (vec2 uv) {
  // At the end, float PI rounds above pi and sin(spread) can turn slightly negative
  if (progress >= 1.0) return getToColor(uv);
  // Measured in square pixels, so the angles are not stretched
  vec2 q = (uv - center) * vec2(ratio, 1.0);
  float a = radians(angle);
  // Local frame: y along the starting direction, x across it (the wedge is symmetric)
  vec2 p = vec2(abs(q.x * cos(a) - q.y * sin(a)), q.x * sin(a) + q.y * cos(a));
  // Each hand has turned by half a turn at the end
  float spread = PI * progress;
  vec2 hand = vec2(sin(spread), cos(spread));
  // Signed distance to the wedge: the nearest hand, negative inside
  float l = length(p);
  float d = length(p - hand * clamp(dot(p, hand), 0.0, l)) * sign(hand.y * p.x - hand.x * p.y);
  // The soft edge keeps an even width and slides from outside to inside the hands,
  // so nothing is revealed at the start and everything is at the end
  float s = max(smoothness, 0.001);
  float m = 1.0 - smoothstep(0.0, s, d + s * (1.0 - progress));
  return mix(getFromColor(uv), getToColor(uv), m);
}
