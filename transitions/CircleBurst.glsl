// Author: gre
// License: MIT
// Description: Discs of three solid colors burst out of a point one after another, each covering the last, then a hole bursts open from the same point in the last one to reveal the incoming image
// Tags: circle, burst, color, reveal, motion-graphics

// @param Point the discs burst out of, in texture coordinates
uniform vec2 center; // = vec2(0.5, 0.5)
// @color Color of the first disc
uniform vec4 color1; // = vec4(0.99, 0.79, 0.29, 1.0)
// @color Color of the second disc
uniform vec4 color2; // = vec4(0.95, 0.38, 0.33, 1.0)
// @color Color of the third disc, which opens onto the incoming image
uniform vec4 color3; // = vec4(0.13, 0.15, 0.3, 1.0)
// @range(0, 1) Delay between the discs, relative to the burst of one disc (at 0, they burst as one: a single circle opens onto the incoming image)
uniform float stagger; // = 0.3

// half width of the antialiased edges, in frame heights
const float AA = 0.0015;
// width and opacity of the soft shadow each disc casts on what is under it
const float SW = 0.03;
const float SO = 0.32;

// local progress of a layer starting at s and lasting d
float phase(float s, float d) {
  return clamp((progress - s) / d, 0.0, 1.0);
}

// radius of the edge of a layer at local progress t: it bursts out of just before the point and
// leaves the frame still moving, its shadow last
float radius(float t, float R) {
  float u = 1.0 - t;
  return mix(-SW - AA, R, mix(t, 1.0 - u * u * u, 0.8));
}

// fold texture coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(abs(v), 2.0));
}

// a layer of color c and radius r laid over p (premultiplied), with its shadow around it, at distance x
vec4 layer(vec4 p, vec4 c, float r, float x) {
  float k = smoothstep(r - AA, r + AA, x);
  float s = SO * c.a * k * (1.0 - smoothstep(0.0, SW, x - r));
  p = p * (1.0 - s) + vec4(0.0, 0.0, 0.0, s);
  k = c.a * (1.0 - k);
  return p * (1.0 - k) + vec4(c.rgb, 1.0) * k;
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float x = length((uv - center) * asp);
  // past the farthest corner, with room for the shadows
  float R = length(max(center, 1.0 - center) * asp) + SW + AA;
  float k = clamp(stagger, 0.0, 1.0);
  float d = 1.0 / (1.0 + 3.0 * k);

  // the outgoing image is pushed in by the first burst
  float t = phase(0.0, d);
  vec4 a = getFromColor(mirror(center + (uv - center) / (1.0 + 0.06 * t * (2.0 - t))));
  vec4 p = vec4(a.rgb * a.a, a.a);
  p = layer(p, color1, radius(t, R), x);
  p = layer(p, color2, radius(phase(k * d, d), R), x);
  float r = radius(phase(2.0 * k * d, d), R);
  p = layer(p, color3, r, x);

  // the hole in the last disc shows the incoming image, which pops in slightly zoomed, overshoots
  // and settles, shaded along the hole's rim as much as the disc around it is wide
  t = phase(3.0 * k * d, d);
  float h = radius(t, R);
  float u = 1.0 - t;
  vec4 b = getToColor(mirror(center + (uv - center) / (1.0 + 0.14 * u * u * (1.0 - 2.4 * t))));
  float s = SO * color3.a * clamp((r - h) / SW, 0.0, 1.0) * (1.0 - smoothstep(0.0, SW, h - x));
  vec4 q = vec4(b.rgb * b.a * (1.0 - s), b.a * (1.0 - s) + s);
  p = mix(p, q, 1.0 - smoothstep(h - AA, h + AA, x));
  return p.a > 0.0 ? vec4(p.rgb / p.a, p.a) : vec4(0.0);
}
