// Author: gre
// License: MIT
// Description: A notched arrowhead window onto the incoming image flies in from the edge behind it (or appears at the center), then swells until it fills the frame
// Tags: shape, wipe, arrow, chevron, directional

// @param Direction the arrow points and flies toward
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0, 0.9) Depth of the notch at the back of the arrowhead (0 for a plain triangle)
uniform float notch; // = 0.4
// @range(20, 160) Opening angle of the arrowhead's tip, in degrees
uniform float width; // = 80.0
// @range(1, 3, 1) Number of nested chevrons flying in a row
uniform int count; // = 1
// @param Grow the arrow from the center of the frame instead of flying it in
uniform bool origin; // = false
// @range(0, 0.1) Softness of the arrow's edges
uniform float smoothness; // = 0.004

// Signed distance (in frame heights) to an arrowhead whose tip is at x = tip and whose notch
// reaches back to x = back, in the arrow's frame (x along the direction, y = |across|)
float arrow(vec2 q, float tip, float back, vec2 tipN, vec2 notchN) {
  float front = dot(vec2(q.x - tip, q.y), tipN);
  float rear = dot(vec2(back - q.x, -q.y), notchN);
  return max(front, rear);
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 across = vec2(-dir.y, dir.x);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  vec2 q = vec2(dot(p, dir), abs(dot(p, across)));

  float s = max(smoothness, 0.001);
  float n = clamp(notch, 0.0, 0.9);
  float h = radians(0.5 * clamp(width, 20.0, 160.0));
  float cot = cos(h) / sin(h);
  // outward normals of the tip's edges and of the notch's edges
  vec2 tipN = vec2(sin(h), cos(h));
  float notchLen = length(vec2(1.0, n * cot));
  vec2 notchN = vec2(1.0, n * cot) / notchLen;
  // how far the tip must pass a point for the soft edge to clear it
  float tipPad = s / sin(h);

  // The frame's corners in the arrow's frame
  vec2 c1 = vec2(0.5 * ratio, 0.5);
  vec2 c2 = vec2(0.5 * ratio, -0.5);
  vec2 k1 = vec2(abs(dot(c1, dir)), abs(dot(c1, across)));
  vec2 k2 = vec2(abs(dot(c2, dir)), abs(dot(c2, across)));
  // half extent of the frame along the direction, and where its back edge crosses the axis
  float e = max(k1.x, k2.x);
  float r = 0.5 / max(abs(dir.x) / ratio, abs(dir.y));
  // To cover the frame, the tip must be ahead of every corner, and the notch behind every
  // corner and behind the back edge's middle (with room for the soft edge)
  float tipMin = max(k1.x + k1.y * cot, k2.x + k2.y * cot) + tipPad;
  float notchMax = min(min(n * cot * k1.y - k1.x, n * cot * k2.y - k2.x), -r) - s * notchLen;

  // The arrow (length 1 from tip to barbs) turns around the middle of its axis: its tip is
  // half its body ahead of that point, its notch half its body behind
  float body = 0.5 * (1.0 - n);
  // The scale at which the arrow centered on the frame covers it
  float cover = max(tipMin, -notchMax) / body;

  float t = progress;
  float o; // middle of the arrow
  float l; // size of the arrow
  if (origin) {
    o = 0.0;
    l = cover * t * (0.4 + 0.6 * t);
  } else {
    // while it flies, its larger side (length or span) is about the frame's smaller side
    float l0 = 0.92 * min(1.0, ratio) / max(1.0, 2.0 * tan(h));
    // starts just behind the frame, flies to the middle, then swells
    float o0 = -e - 2.0 * tipPad - body * l0;
    // it is already moving when it enters, and slows down as it starts to swell
    float u = 1.0 - clamp(t / 0.65, 0.0, 1.0);
    float fly = 1.0 - u * u * u;
    // the swell speeds up and still moves at the end, so the last corners do not linger
    float grow = clamp((t - 0.3) / 0.7, 0.0, 1.0);
    o = mix(o0, 0.0, fly);
    l = mix(l0, cover, grow * grow * (2.0 - grow));
  }

  // the nested chevrons follow the first one, each tucked behind the previous one's notch
  float gap = (1.0 - n) * 1.35;
  float d = arrow(q, o + body * l, o - body * l, tipN, notchN);
  for (int i = 1; i < 3; i++) {
    if (i < count) {
      float back = o - float(i) * gap * l;
      d = min(d, arrow(q, back + body * l, back - body * l, tipN, notchN));
    }
  }
  // the soft edge slides from outside the arrow to inside it, so nothing shows at the start
  float m = 1.0 - smoothstep(-s, s, d + 2.0 * s * (1.0 - t));

  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
