// Author: gre
// License: MIT
// Description: The incoming image appears nested in the outgoing one, which is nested in it again, on and on along a spiral, and the camera spirals in until the incoming image fills the frame
// Tags: zoom, spiral, recursive, rotate

// @range(-0.5, 0.5) How much each nested image is turned inside the one around it, in turns
uniform float turns; // = 0.12
// @range(-0.5, 0.5) How much the nested images bend along a logarithmic spiral, in turns per nesting level
uniform float twist; // = 0.06
// @param Point the camera dives into (0 to 1 on both axes)
uniform vec2 center; // = vec2(0.5, 0.5)

const float TAU = 6.283185307179586;
// natural log of the size ratio between two nested images, halfway through (3x)
const float DEPTH = 1.1;
// width of the anti-aliased edges of the nested images, in frame heights
const float EDGE = 0.0025;
// darkness of the shadow under the nested images
const float SHADOW = 0.45;

vec2 rotate2(vec2 v, float a) {
  float c = cos(a);
  float s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// 1 on the border of the frame's rectangle around the center, less inside it
float rectNorm(vec2 q, vec2 lo, vec2 hi) {
  return max(max(q.x / hi.x, -q.x / lo.x), max(q.y / hi.y, -q.y / lo.y));
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  vec2 c = clamp(center, 0.05, 0.95);
  vec2 asp = vec2(ratio, 1.0);
  // the frame's extent around the center, in frame heights
  vec2 lo = c * asp;
  vec2 hi = (1.0 - c) * asp;
  float minExtent = min(min(lo.x, lo.y), min(hi.x, hi.y));
  vec2 d = (uv - c) * asp;

  float p = progress;
  // the camera's dive, in nesting levels: from the outgoing image (0) to the incoming one (1)
  float t = p * p * p * (p * (p * 6.0 - 15.0) + 10.0);
  // nesting levels per unit of log scale: 0 at both ends, where the nested images shrink to nothing
  float env = 4.0 * p * (1.0 - p);
  float g = env / DEPTH;
  float gs = max(g, 1e-6);

  float r = max(length(d), 1e-6);
  // bend along a logarithmic spiral, more and more toward the center
  d = rotate2(d, TAU * twist * g * log(r));

  // start one level outside the outermost one that can cover this point, so that its soft
  // edges blend over the image around it; the outgoing image is the outermost one
  float k0 = max(floor(t - g * log(r / minExtent)) - 1.0, 0.0);
  float edge = EDGE * min(1.0, 10.0 * env) + 1e-6;

  vec4 color = vec4(0.0);
  for (int i = 0; i < 12; i++) {
    float k = k0 + float(i);
    // level k on screen: scaled by exp((t - k) / g), turned by (k - t) * turns
    float e = clamp((k - t) / gs, -40.0, 40.0);
    float scale = exp(-e);
    // the deepest levels fade in from a few pixels, which keeps the center clean
    float fade = smoothstep(0.004, 0.02, scale);
    if (fade <= 0.0) break;
    vec2 q = rotate2(d, -TAU * turns * (k - t)) * exp(e);
    float n = rectNorm(q, lo, hi);
    // signed distance to the image's border on screen, roughly, in units of edge widths
    float dist = (1.0 - n) * minExtent * scale / edge;
    // the outgoing image fills the frame (mirrored where it turns away from the corners)
    float cover = k == 0.0 ? 1.0 : clamp(dist, 0.0, 1.0) * fade;
    // a soft shadow under each nested image
    color.rgb *= 1.0 - SHADOW * env * fade * smoothstep(-12.0, 0.0, dist) * step(0.5, k);
    if (cover <= 0.0) continue;
    vec2 st = mirror(c + q / asp);
    vec4 img = mod(k, 2.0) < 0.5 ? getFromColor(st) : getToColor(st);
    color = mix(color, img, cover);
  }
  return color;
}
