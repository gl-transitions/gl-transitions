// Author: gre
// License: MIT
// Description: Solid color panels, slightly staggered, sweep across and cover the frame, then sweep off the far side and reveal the incoming image
// Tags: wipe, panels, color, slanted, motion-graphics

// @param Direction the panels sweep toward
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(1, 3, 1) Number of panels
uniform int panels; // = 3
// @color Color of the first panel
uniform vec4 color1; // = vec4(0.98, 0.76, 0.22, 1.0)
// @color Color of the second panel
uniform vec4 color2; // = vec4(0.93, 0.33, 0.36, 1.0)
// @color Color of the third panel
uniform vec4 color3; // = vec4(0.16, 0.2, 0.42, 1.0)
// @range(0, 1) Delay between the panels, relative to the sweep of one panel (at 0, they move as one and only the last shows)
uniform float stagger; // = 0.35
// @range(-1, 1) Slant of the panels' edges
uniform float skew; // = 0.25

// the frame is fully covered from cut - hold to cut + hold, where the image switches
const float cut = 0.46;
const float hold = 0.01;
// half width of the antialiased edges, in frame heights
const float aa = 0.0015;

// a short acceleration, a fast sweep, and a long settle
float ease(float t) {
  float s = clamp(t, 0.0, 1.0);
  float u = 1.0 - s * s * (3.0 - 2.0 * s);
  return 1.0 - u * u * u;
}

// how much of x a panel between the edges back and front covers
float cover(float x, float back, float front) {
  return smoothstep(back - aa, back + aa, x) * (1.0 - smoothstep(front - aa, front + aa, x));
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float k = clamp(skew, -1.0, 1.0);
  // position along the sweep, slanted across it, in frame heights across the edges
  vec2 a = (dir + k * vec2(-dir.y, dir.x)) / sqrt(1.0 + k * k);
  float x = dot(p, a);
  // half extent of the frame along x
  float e = 0.5 * (abs(a.x) * ratio + abs(a.y));
  float start = -e - 2.0 * aa;
  float span = 2.0 * (e + 2.0 * aa);

  int n = panels < 1 ? 1 : panels > 3 ? 3 : panels;
  float m = float(n - 1);
  float st = clamp(stagger, 0.0, 1.0);
  // durations of a panel's sweep in and out
  vec2 d = vec2(cut - hold, 1.0 - cut - hold) / (1.0 + m * st);

  // the first panel enters first and leaves last: the outgoing image is ahead of it, the incoming one behind it
  // (both are sampled, so that no texture read sits in a branch that differs between pixels)
  float front0 = start + span * ease(progress / d.x);
  float back0 = start + span * ease((progress - 1.0 + d.y) / d.y);
  vec4 c = mix(getToColor(uv), getFromColor(uv), step(0.5 * (front0 + back0), x));
  c = mix(c, color1, cover(x, back0, front0));

  // each next panel covers the ones before it, enters after them and leaves before them
  for (int i = 1; i < 3; i++) {
    if (i < n) {
      vec2 t = float(i) * st * d;
      float front = start + span * ease((progress - t.x) / d.x);
      float back = start + span * ease((progress - 1.0 + d.y + t.y) / d.y);
      c = mix(c, i == 1 ? color2 : color3, cover(x, back, front));
    }
  }
  return c.a > 0.0 ? c : vec4(0.0);
}
