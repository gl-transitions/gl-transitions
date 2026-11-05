// Author: gre
// License: MIT
// Description: A rectangle anchored in a corner, on an edge or in the center grows until the incoming image fills the frame, revealing it in place without scaling it; in reverse, the outgoing image shrinks into the rectangle
// Tags: wipe, shape, box

// @param Where the rectangle grows from: (0, 0) bottom left, (1, 1) top right, (0.5, 0) middle of the bottom edge, (0.5, 0.5) center
uniform vec2 anchor; // = vec2(1.0, 1.0)
// @range(0, 0.2) Softness of the rectangle's edge
uniform float smoothness; // = 0.0
// @range(0, 0.1) Width of a border drawn around the rectangle, in frame heights (0: no border)
uniform float borderWidth; // = 0.0
// @color Color of the border
uniform vec4 borderColor; // = vec4(1.0, 1.0, 1.0, 1.0)
// @param The outgoing image shrinks into the rectangle instead, toward the anchor
uniform bool reverse; // = false

// half width of the antialiased edge, in frame heights
const float AA = 0.001;

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  vec2 an = clamp(anchor, 0.0, 1.0);
  vec2 sq = vec2(ratio, 1.0);
  // the rectangle keeps the proportions that make it reach every far side of the frame
  // at once; measured in square pixels so its edge and border have an even width
  vec2 ext = max(an, 1.0 - an) * sq;
  vec2 d = abs(uv - an) * sq;
  float s = max(smoothness, AA);
  float bw = max(borderWidth, 0.0);

  // eased growth, from a rectangle whose border is not yet in the frame to one whose
  // soft edge has left it on every side
  float t = reverse ? 1.0 - progress : progress;
  float p = mix(t, t * t * (3.0 - 2.0 * t), 0.3);
  vec2 size = p * ext + mix(-(bw + s), s, p);
  // signed distance to the rectangle's edge, square-cornered, < 0 inside
  float e = max(d.x - size.x, d.y - size.y);

  // the rectangle shows the incoming image, or the outgoing one in reverse
  vec4 inside = reverse ? a : b;
  vec4 c = premultiplied(reverse ? b : a);
  if (bw > 0.0) {
    // laid over the image outside the rectangle, so a translucent border tints it
    float m = 1.0 - smoothstep(bw - s, bw + s, e);
    c = premultiplied(borderColor) * m + c * (1.0 - borderColor.a * m);
  }
  c = mix(c, premultiplied(inside), 1.0 - smoothstep(-s, s, e));
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
