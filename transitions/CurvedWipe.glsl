// Author: gre
// License: MIT
// Description: The outgoing image is pulled away by its middle: the wipe edge bulges into a smooth curve that leads the way, then flattens as it reaches the far side
// Tags: wipe, curve, directional, shadow

// @param Direction the edge moves toward
uniform vec2 direction; // = vec2(0.0, 1.0)
// @range(0, 1) How far the middle of the edge leads its sides
uniform float curvature; // = 0.6
// @range(0, 0.2) Softness of the edge
uniform float smoothness; // = 0.02
// @color Color of the soft shadow the lifted edge casts on the incoming image (its alpha is its strength; 0 for none)
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.4)

const float PI = 3.141592653589793;

// a gentle ease in and out, which does not linger at the ends
float ease (float t) {
  return 0.5 * (t + t * t * (3.0 - 2.0 * t));
}

vec4 transition (vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(0.0, 1.0);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  // half extents of the frame along the direction and across it
  float e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float w = 0.5 * (abs(dir.y) * ratio + abs(dir.x));
  vec2 across = vec2(-dir.y, dir.x);
  float d = dot(p, dir);
  // where the pixel is across the frame, from -1 to 1 (on a diagonal, these are the corners); it is the same
  // all along the direction, so the edge is a single curve, centered on the middle of the frame
  float x = clamp(dot(p, across) / w, -1.0, 1.0);
  float s = max(smoothness, 0.001);
  // each point of the edge runs on its own clock: the middle runs ahead and slows down at the far side,
  // where the sides catch up with it; the lead keeps the curve's shape alike on wide and narrow frames
  float k = clamp(curvature, 0.0, 1.0) * min(1.0, w / e) * (1.0 - x * x);
  float t = progress + k * progress * (1.0 - progress);
  float travel = 2.0 * (e + s);
  float edge = -e - s + travel * ease(t);
  float side = -e - s + travel * ease(progress);
  float m = 1.0 - smoothstep(-s, s, d - edge);
  // the more the edge is lifted, the wider and softer the shadow it casts on the incoming image
  float lift = edge - side;
  float spread = 0.012 + 0.25 * lift;
  // it falls behind the edge only, on the incoming image, cast by the outgoing image at the edge
  vec4 to = getToColor(uv);
  vec2 caster = clamp((p + (edge - d) * dir) / vec2(ratio, 1.0) + 0.5, 0.0, 1.0);
  float sh = shadow.a * sin(PI * progress) * exp(-max(edge - d, 0.0) / spread) * m * getFromColor(caster).a * to.a;
  to.rgb = mix(to.rgb, shadow.rgb, sh);
  return mix(getFromColor(uv), to, m);
}
