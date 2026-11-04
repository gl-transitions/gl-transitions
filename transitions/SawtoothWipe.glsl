// Author: gre
// License: MIT
// Description: A wipe whose edge is a row of sharp, regular triangular teeth sweeps across the frame, or two toothed edges that start interlocked part from the middle like jaws opening
// Tags: wipe, shape, directional, zigzag

// @param Direction the toothed edge moves toward (with jaws, the axis along which the two edges part)
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(1, 40, 1) Number of teeth along the edge
uniform int teeth; // = 8
// @range(0, 3) Length of the teeth, relative to their width
uniform float depth; // = 1.0
// @param Two toothed edges part from the middle instead of one sweeping across
uniform bool jaws; // = false
// @range(0, 0.1) Softness of the edge
uniform float smoothness; // = 0.004

// half width of the antialiased edge, in frame heights
const float AA = 0.0015;

// signed distance to a zigzag line of period w and peak-to-peak height h, centered on y = 0,
// its tips pointing up at x = 0; positive above it
float zigzag(vec2 q, float w, float h) {
  // fold into half a tooth: the slope from the bottom of a notch to the tip of a tooth
  float x = abs(fract(q.x / w) - 0.5) * w;
  vec2 a = vec2(0.0, -0.5 * h);
  vec2 ab = vec2(0.5 * w, h);
  vec2 aq = vec2(x, q.y) - a;
  float d = length(aq - ab * clamp(dot(aq, ab) / dot(ab, ab), 0.0, 1.0));
  return q.y > h * (2.0 * x / w - 0.5) ? d : -d;
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  // measured in square pixels, so the teeth are not stretched
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  // half extents of the frame along the direction and across it
  float e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float w = 0.5 * (abs(dir.y) * ratio + abs(dir.x));
  float period = 2.0 * w / float(teeth < 1 ? 1 : teeth);
  // position across the edge, with the notches on the sides of the frame so that it shows
  // whole teeth, and along the direction
  vec2 q = vec2(dot(p, vec2(-dir.y, dir.x)) + w + 0.5 * period, dot(p, dir));
  float h = max(depth, 0.0) * period;
  // the soft edge never gets wide enough to blur small teeth away
  float s = max(min(smoothness, 0.25 * period), AA);
  float t = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.35);

  float d;
  if (jaws) {
    // the two edges are the same zigzag, interlocked at the start (crossed by the soft
    // edge, measured across the slopes of the teeth), then moving apart until each one
    // has left the frame on its side
    float overlap = s * sqrt(1.0 + 4.0 * h * h / (period * period));
    float o = mix(-overlap, e + 0.5 * h + s, t);
    d = max(zigzag(q - vec2(0.0, o), period, h), -zigzag(q + vec2(0.0, o), period, h));
  } else {
    // the edge starts fully ahead of the frame and ends fully past it
    float c = mix(-e - 0.5 * h - s, e + 0.5 * h + s, t);
    d = zigzag(q - vec2(0.0, c), period, h);
  }
  // > 0 where the incoming image shows
  float m = 1.0 - smoothstep(-s, s, d);

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
