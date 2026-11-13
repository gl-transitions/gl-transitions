// Author: gre
// License: MIT
// Description: The outgoing image is a paper cutout that jerks off the frame in choppy stop-motion steps, with a tiny new tilt and offset each step and a drop shadow, while the incoming cutout jerks in the same way and lands
// Tags: stop-motion, paper, cutout, slide, shadow, choppy

// @range(6, 30, 1) Number of held poses during the transition: fewer is choppier
uniform int steps; // = 12
// @range(0, 1) Size of the small random tilt and offset given to the cutouts at each step
uniform float jitter; // = 0.5
// @range(0, 1) Darkness of the drop shadow the cutouts cast
uniform float shadow; // = 0.5
// @color Color of the background behind the cutouts
uniform vec4 backColor; // = vec4(0.80, 0.71, 0.56, 1.0)
// @color Color of the paper rim around the cutouts
uniform vec4 rimColor; // = vec4(0.97, 0.96, 0.93, 1.0)

const float SHRINK = 0.2; // how much smaller the cutouts are than the frame while they move
const float RIM = 0.012; // width of the paper rim around the cutouts, in frame heights
const float RADIUS = 0.006; // corner radius of the cutouts, in frame heights
const float AA = 0.0015; // width of the antialiased edges, in frame heights

// Hoskins' hash of an integer step
float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

// signed distance to a rounded box of half size b and corner radius r
float roundedBox(vec2 q, vec2 b, float r) {
  vec2 d = abs(q) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// distance from the center far enough for a cutout of half size h turned by a, and its shadow, to be out of the frame
float offFrame(vec2 h, float a) {
  return 0.5 * ratio + abs(cos(a)) * h.x + abs(sin(a)) * h.y + 0.08;
}

// half size of a cutout scaled by s, with its rim for the lift l
vec2 cutoutSize(float s, float l) {
  return (0.5 * vec2(ratio, 1.0) + RIM * l) * s;
}

// draws over col (premultiplied) a cutout of the outgoing or incoming image, centered at c, turned by a, scaled by s, lifted by l
vec4 drawCutout(vec4 col, vec2 q, vec2 c, float a, float s, float l, bool incoming) {
  vec2 asp = vec2(ratio, 1.0);
  vec2 halfImage = 0.5 * asp;
  vec2 halfCut = halfImage + RIM * l;
  float rad = RADIUS * l;
  float ca = cos(a), sa = sin(a);
  mat2 unrotate = mat2(ca, -sa, sa, ca);

  // the drop shadow, cast down and to the right, softer and further as the cutout is lifted,
  // as dark as the image casting it is opaque
  vec2 rs = unrotate * (q - c - vec2(0.018, -0.026) * l) / s;
  vec2 ss = clamp(rs / asp + 0.5, 0.0, 1.0);
  float sAlpha = max(incoming ? getToColor(ss).a : getFromColor(ss).a, rimColor.a);
  float ds = roundedBox(rs, halfCut, rad) * s;
  float blur = 0.004 + 0.016 * l;
  col.rgb *= 1.0 - clamp(shadow, 0.0, 1.0) * 0.75 * l * sAlpha * (1.0 - smoothstep(-blur, blur, ds));

  vec2 r = unrotate * (q - c) / s;
  float dCut = roundedBox(r, halfCut, rad) * s;
  float dImage = roundedBox(r, halfImage, 0.0) * s;
  float cutCover = clamp(0.5 - dCut / AA, 0.0, 1.0);
  float imageCover = clamp(0.5 - dImage / AA, 0.0, 1.0);
  vec2 st = clamp(r / asp + 0.5, 0.0, 1.0);
  vec4 img = premultiply(incoming ? getToColor(st) : getFromColor(st));
  // the image on its paper rim, laid over what is below
  vec4 cut = mix(premultiply(rimColor), img, imageCover) * cutCover;
  return cut + col * (1.0 - cut.a);
}

vec4 transition(vec2 uv) {
  float n = float(steps < 2 ? 2 : steps);
  // the pose held at this time: the first and last are the full images, held half a step each
  float k = floor(progress * n + 0.5);
  if (k <= 0.0) return getFromColor(uv);
  if (k >= n) return getToColor(uv);

  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float j = clamp(jitter, 0.0, 1.0);

  // the outgoing cutout is picked up off the frame in two poses, then jerked out to the left, faster and faster
  float l0 = min(k / 2.0, 1.0);
  float m0 = clamp((k - 1.0) / (0.45 * n), 0.0, 1.0);
  m0 = m0 * m0 * (0.4 + 0.6 * m0);
  float s0 = 1.0 - SHRINK * l0;
  float a0 = 0.22 * m0 + l0 * j * 0.2 * (hash11(k) - 0.5);
  vec2 c0 = vec2(-offFrame(cutoutSize(s0, l0), a0) * m0, 0.05 * m0 * m0)
    + l0 * j * vec2(0.07 * (hash11(k + 100.0) - 0.5), 0.05 * (hash11(k + 200.0) - 0.5));

  // the incoming cutout is jerked in from the right, slowing down, then laid flat onto the frame in two poses
  float l1 = min((n - k) / 2.0, 1.0);
  float m1 = clamp((n - 2.0 - k) / (0.45 * n), 0.0, 1.0);
  m1 = m1 * m1 * (0.4 + 0.6 * m1);
  float s1 = 1.0 - SHRINK * l1;
  float a1 = -0.25 * m1 + l1 * j * 0.2 * (hash11(k + 300.0) - 0.5);
  vec2 c1 = vec2(offFrame(cutoutSize(s1, l1), a1) * m1, -0.06 * m1 * m1)
    + l1 * j * vec2(0.07 * (hash11(k + 400.0) - 0.5), 0.05 * (hash11(k + 500.0) - 0.5));

  // the background, then the outgoing cutout, then the incoming one on top
  vec4 col = premultiply(backColor);
  if (m0 < 1.0) col = drawCutout(col, q, c0, a0, s0, l0, false);
  if (m1 < 1.0) col = drawCutout(col, q, c1, a1, s1, l1, true);
  if (col.a <= 0.0) return vec4(0.0);
  col.rgb /= col.a;
  // the light dims a little from one shot to the next
  col.rgb *= 1.0 - 0.04 * j * hash11(k + 600.0);
  return col;
}
