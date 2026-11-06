// Author: gre
// License: MIT
// Description: The incoming image slides in over the outgoing one, which moves away in the same direction but more slowly and darkens beneath it, in the soft shadow cast by the incoming image's leading edge
// Tags: slide, push, parallax, shadow, directional

// @param Direction in which the images move, snapped to its main axis (left, right, up or down)
uniform vec2 direction; // = vec2(-1.0, 0.0)
// @range(0, 1) How far the outgoing image travels, as a fraction of the incoming one's travel
uniform float parallax; // = 0.4
// @range(0, 1) Strength and size of the shadow cast by the incoming image's leading edge
uniform float shadow; // = 0.5
// @range(0, 1) How dark the outgoing image gets beneath the incoming one
uniform float dim; // = 0.5

// folds a coordinate back into 0..1, mirroring the image beyond its edges
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  // the main axis of the direction, from the right when there is none
  vec2 d = abs(direction.x) >= abs(direction.y)
    ? vec2(direction.x <= 0.0 ? -1.0 : 1.0, 0.0)
    : vec2(0.0, sign(direction.y));
  float p = progress;
  // eased in and out, with a little linear motion so that it never stands still
  float e = 0.85 * p * p * (3.0 - 2.0 * p) + 0.15 * p;

  // the incoming image, on top: arrives from the side opposite to the direction
  vec2 t = uv + d * (1.0 - e);
  // how far inside it, from its leading edge (negative outside), in frame units along the axis
  float ta = dot(t, abs(d));
  float inside = d.x + d.y > 0.0 ? 1.0 - ta : ta;
  // its leading edge is antialiased over about a pixel while it moves, sharp at both ends
  float w = 0.0015 * clamp(40.0 * min(e, 1.0 - e), 0.0, 1.0);
  float cover = w > 0.0 ? clamp(inside / w + 0.5, 0.0, 1.0) : step(0.0, inside);
  vec4 next = getToColor(clamp(t, 0.0, 1.0));
  if (cover >= 1.0) return next;

  // the outgoing image, beneath: moves the same way, but only part of the distance
  vec4 c = getFromColor(mirror(uv - d * parallax * e));

  // the shadow of its leading edge, relative to the shorter side of the frame: soft,
  // and it builds up as the image starts moving
  float dist = max(-inside, 0.0) * (d.x != 0.0 ? ratio : 1.0) / min(ratio, 1.0);
  float sh = clamp(shadow, 0.0, 1.0);
  float k = clamp(1.0 - dist / (0.03 + 0.27 * sh), 0.0, 1.0);
  float shade = min(0.9, 1.4 * sh) * k * k * smoothstep(0.0, 0.2, p);
  float light = (1.0 - clamp(dim, 0.0, 1.0) * e) * (1.0 - shade);
  return mix(vec4(c.rgb * light, c.a), next, cover);
}
