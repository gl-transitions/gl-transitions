// Author: gre
// License: MIT
// Description: The outgoing image stretches out long as it shoots away to one side, pulling in the incoming one squashed behind it, which overshoots and springs back to its shape
// Tags: slide, stretch, squash, elastic, bounce, directional

// @param Direction in which the images slide
uniform vec2 direction; // = vec2(-1.0, 0.0)
// @range(0, 1) How long the outgoing image stretches and how much the squashed incoming one bulges
uniform float stretch; // = 0.6
// @range(0, 1) How far the incoming image overshoots before it springs back to its shape
uniform float bounce; // = 0.6

const float PI = 3.14159265;

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float dl = length(direction);
  vec2 d = dl > 1e-6 ? direction / dl : vec2(-1.0, 0.0);
  vec2 n = vec2(-d.y, d.x);
  // s: position along the slide across the frame, from 0 (trailing side) to 1 (leading side)
  float ext = abs(d.x) + abs(d.y);
  vec2 q = uv - 0.5;
  float s = 0.5 + dot(q, d) / ext;
  float t = progress;

  // the slide accelerates into the landing (a smoothstep when there is no bounce)
  float land = mix(1.0, 0.5, bounce);
  float m = 3.0 * bounce; // speed at the landing, relative to a linear slide
  float x = clamp(t / land, 0.0, 1.0);
  float e = x * x * (3.0 - 2.0 * x) + m * x * x * (x - 1.0);
  // then a damped spring, starting at the landing speed, that comes to rest exactly at the end
  float w = 2.5 * PI;
  float u = clamp((t - land) / max(1.0 - land, 1e-4), 0.0, 1.0);
  float osc = m * (1.0 - land) / (land * w) * exp(-u) * sin(w * u) * (1.0 - u) * (1.0 - u);
  // past the landing the frame stays covered: the spring stretches the incoming image
  // along the slide, and squashes it back into a sideways bulge
  float len = e + max(osc, 0.0);
  float bulge = 1.0 - e + 3.0 * max(-osc, 0.0);

  // the incoming image is pinned at the trailing side and spans up to the seam
  float g = 1.0 + 0.6 * stretch * bulge;
  vec2 pt = q + d * (s / max(len, 1e-4) - s) * ext;
  pt -= n * dot(pt, n) * (1.0 - 1.0 / g);
  vec4 b = getToColor(mirror(pt + 0.5));

  // the outgoing image hangs from the seam and stretches out long ahead of it,
  // the most near the seam, where it is pulled
  float l = 1.0 + 4.0 * stretch * e;
  float k = clamp(1.6 * stretch * e, 0.0, 0.8);
  float y = max(s - e, 0.0) / l;
  // invert y = (1 + k) v - k v^2
  float v = 2.0 * y / ((1.0 + k) + sqrt((1.0 + k) * (1.0 + k) - 4.0 * k * y));
  vec4 a = getFromColor(mirror(q + d * (v - s) * ext + 0.5));

  // past the landing, only the incoming image is left
  return (s < len || t >= land) ? b : a;
}
