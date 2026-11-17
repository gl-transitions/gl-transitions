// Author: gre
// License: MIT
// Description: The incoming picture arrives wound on a heavy roller that rolls across the outgoing one from left to right, pressing it down and bunching it up in its shadow just ahead of its contact line, and lays the incoming picture down flat behind it as it unrolls
// Tags: roller, cylinder, press, directional, 3d

// @range(0.06, 0.3) Radius of the roller, in frame heights (frame widths in portrait)
uniform float radius; // = 0.15
// @range(0, 1) How hard the roller presses the outgoing picture: bunching and shadow ahead of it
uniform float press; // = 0.7

const float PI = 3.141592653589793;

vec2 mirrored(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

vec4 transition(vec2 uv) {
  float t = progress * progress * (3.0 - 2.0 * progress);
  float r = radius * min(ratio, 1.0);
  float X = uv.x * ratio;
  float xc = mix(-r - 0.02, ratio + r + 0.02, t);
  float A = press * smoothstep(0.0, r, xc + r) * (1.0 - smoothstep(0.94, 1.0, progress));
  float L = 0.7 * r;
  float u = max(X - xc - r, 0.0) / L;

  // pulling the sample back by a decaying amount compresses the picture into the ridge without folding it
  vec4 a = getFromColor(mirrored(vec2(uv.x - 1.6 * L * A * exp(-u) / ratio, uv.y)));
  a.rgb *= 1.0 - A * (0.45 * exp(-u / 0.35) + 0.35 * exp(-u / 1.2));

  vec4 b = getToColor(uv);
  b.rgb *= 1.0 - 0.4 * A * (1.0 - smoothstep(0.0, 0.4 * r, xc - r - X));
  vec4 col = X < xc ? b : a;

  float ph = asin(clamp((X - xc) / r, -1.0, 1.0));
  // the wound sheet leaves the roller at the hidden contact line under its axis, so rows count from there around the front
  float row = xc + r * (PI - ph);
  float zoom = 1.0 + 0.3 * r * (1.0 + cos(ph));
  vec4 c = getToColor(mirrored(vec2(row / ratio, 0.5 + (uv.y - 0.5) / zoom)));
  c.rgb = c.rgb * (0.4 + 0.65 * max(cos(ph + 0.5), 0.0)) + 0.3 * c.a * pow(max(cos(ph + 0.6), 0.0), 40.0);
  return mix(col, c, smoothstep(0.0, 0.004, r - abs(X - xc)));
}
