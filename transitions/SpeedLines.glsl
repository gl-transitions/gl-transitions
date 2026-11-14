// Author: gre
// License: MIT
// Description: Comic-style speed lines shoot in from the edges of the frame toward a focus point as the outgoing image punches in; at the peak it cuts to the incoming image, which settles back as the lines retract to the edges
// Tags: comic, lines, radial, zoom, stylized

// @param Point the lines converge to, from (0, 0) at the bottom left to (1, 1) at the top right
uniform vec2 center; // = vec2(0.5, 0.5)
// @color Color of the lines
uniform vec4 lineColor; // = vec4(1.0, 1.0, 1.0, 1.0)
// @range(30, 240) Number of lines around the focus point
uniform float density; // = 110.0
// @range(0, 1) Size of the clear area around the focus point at the peak, from almost nothing to the whole frame
uniform float focus; // = 0.35
// @range(0, 0.5) How much the images punch in toward the focus point
uniform float zoom; // = 0.12

const float PI = 3.141592653589793;
// half width of the antialiased edges, in frame heights
const float AA = 0.0012;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// how far the lines are in, from 0 (all out of the frame) to 1 (peak), for a line with random h:
// each line shoots in up to a little later than the others and retracts the same way
float reachOf(float h) {
  float d = 0.05 * h;
  // fast at first, slowing down as the lines close in, then the other way round on the way out
  float a = 1.0 - clamp((progress - d) / 0.4, 0.0, 1.0);
  float b = clamp((progress - 0.5 - d) / 0.4, 0.0, 1.0);
  return (1.0 - a * a * a) * (1.0 - b * b * b);
}

// coverage of one layer of lines: n angular cells around the focus point (a in 0..1),
// at most one tapered line per cell. e is the elliptical radius (1 at the edges of the frame),
// r the radius in frame heights, E the elliptical radius where the ray leaves the frame
float layer(float a, float e, float r, float n, float seed, float E) {
  // (a can be exactly 1, which is cell 0 again)
  float cell = mod(floor(a * n), n);
  float h1 = hash12(vec2(cell, seed));
  float h2 = hash12(vec2(cell, seed + 7.0));
  float h3 = hash12(vec2(cell, seed + 13.0));
  // a line in most cells
  float on = step(0.22, h1);
  // where the tip of the line is at the peak, then where it is now
  // the lines are redrawn a dozen times along the way, each time a bit longer or shorter
  float h4 = hash12(vec2(cell, seed + 50.0 + floor(progress * 12.0)));
  // (a share of the way from the frame's edge to the focus point, so that the burst stays even
  // when the focus point is off-center)
  float len = 1.0 - 0.85 * h2 * h2 - 0.15 * h4;
  float tipPeak = E * (1.0 - (1.0 - focus) * (0.55 + 0.45 * len));
  float tip = mix(E + 0.05, tipPeak, reachOf(h3));
  // the line widens from a sharp tip to its full width over a taper length
  float t = clamp((e - tip) / max(E * (0.2 + 0.5 * h2), 1e-4), 0.0, 1.0);
  float cellWidth = 2.0 * PI * r / n;
  // its position across the cell, and its width, kept so that its antialiased edges stay in the cell
  float offset = 0.3 + 0.4 * h3;
  float width = min(cellWidth * (0.06 + 0.22 * h1) * sqrt(t), (0.5 - abs(offset - 0.5)) * cellWidth - AA);
  float across = abs(fract(a * n) - offset) * cellWidth;
  return on * (1.0 - smoothstep(width - AA, width + AA, across)) * step(tip, e);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 d = (uv - center) * asp;
  float r = length(d);
  // (nudged off zero, where atan is undefined)
  float a = atan(d.y, d.x + 1e-6) / (2.0 * PI) + 0.5;
  // elliptical radius, following the shape of the frame: 1 at the middle of its edges
  // when the focus point is in the middle
  float e = length((uv - center) * 2.0);
  // where the ray from the focus point through this pixel leaves the frame, so that every line
  // enters the frame at once
  vec2 w = uv - center;
  vec2 room = vec2(w.x > 0.0 ? 1.0 - center.x : center.x, w.y > 0.0 ? 1.0 - center.y : center.y);
  vec2 exits = room / max(abs(w), vec2(1e-6));
  float E = e * min(exits.x, exits.y);

  // the punch in: eased in toward the cut, then the incoming image eases back out of it
  float k = p < 0.5 ? smoothstep(0.0, 0.5, p) : 1.0 - smoothstep(0.5, 1.0, p);
  float s = 1.0 - zoom * k * k;
  // (between the focus point and uv, so in the frame)
  vec2 q = center + (uv - center) * s;
  vec4 c = p < 0.5 ? getFromColor(q) : getToColor(q);

  // two interleaved layers of lines so that their spacing looks random
  float n = max(floor(density), 2.0);
  float l = layer(a, e, r, n, 1.0, E);
  l = max(l, layer(fract(a + 0.5 / n), e, r, n, 31.0, E));
  l *= lineColor.a;

  // lines laid over the image (premultiplied)
  vec4 pc = vec4(c.rgb * c.a, c.a);
  pc = pc * (1.0 - l) + vec4(lineColor.rgb, 1.0) * l;
  return pc.a > 0.0 ? vec4(pc.rgb / pc.a, pc.a) : vec4(0.0);
}
