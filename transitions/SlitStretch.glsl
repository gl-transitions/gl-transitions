// Author: gre
// License: MIT
// Description: The outgoing image is a sheet cut with rows of staggered slits that is pulled from both ends: it lengthens, the slits open into diamonds and the strands between them twist and thin out like expanded metal until only the incoming image is left behind
// Tags: paper, stretch, pattern, 3d, shadow

// @range(0.05, 0.4) Length of a slit and its bridge, relative to the image height
uniform float size; // = 0.16
// @range(0, 3) How much the sheet lengthens as it is pulled
uniform float stretch; // = 1.6
// @range(0, 1) Strength of the shading of the twisting strands and of their shadow
uniform float shading; // = 0.7
// @range(0, 1) How much the sheet narrows at its waist as it is pulled
uniform float neck; // = 0.8
// @param Pull the sheet sideways instead, with vertical slits
uniform bool horizontal; // = false

vec4 transition(vec2 uv) {
  float t = progress;
  // one eased pull
  float q = t * t * (3.0 - 2.0 * t);
  if (q <= 0.0) return getFromColor(uv);
  vec2 asp = vec2(ratio, 1.0);
  // work with the slits along x and the pull along y
  vec2 p = (uv - 0.5) * asp;
  if (horizontal) p = p.yx;
  // the sheet lengthens from its middle and narrows at its waist, held full width at both ends
  float Sy = 1.0 + stretch * q;
  // (ys: -0.5 to 0.5 along the sheet's length)
  float ys = clamp(p.y / (Sy * (horizontal ? ratio : 1.0)), -0.5, 0.5);
  float hw = 0.5 * (horizontal ? 1.0 : ratio);
  float wf = 1.0 - 0.7 * neck * q * (1.0 - 4.0 * ys * ys);
  // (no edge on the frame's border at the start)
  float side = (hw * wf - abs(p.x)) / (0.003 * min(1.0, 200.0 * q) + 1e-7);
  p.x /= wf;
  float a = 0.5 * size;
  // the rows of slits spread apart as the sheet lengthens
  float b = 0.22 * size * Sy;
  // cell of the diamond lattice (staggered rows)
  float j = floor(p.y / b + 0.5);
  float xo = mod(j, 2.0) * a;
  float i = floor((p.x - xo) / (2.0 * a) + 0.5);
  vec2 c = vec2(i * 2.0 * a + xo, j * b);
  vec2 d = p - c;
  // check the two neighbouring rows too: the diamonds interlock
  vec2 d2 = p - vec2(c.x + (p.x > c.x ? a : -a), c.y + (p.y > c.y ? b : -b));
  if (abs(d2.x) / a + abs(d2.y) / b < abs(d.x) / a + abs(d.y) / b) d = d2;

  // the hole: a slit (the bridges between slits keep the sheet whole) that opens into a diamond,
  // slightly larger than the cell at the end, so the strands have gone edge-on
  float grow = 1.0 + 0.12 * q;
  float A = max(a * mix(0.72, 1.0, q) * grow, 1e-4);
  float H = max(b * sqrt(q) * grow, 1e-5);
  float f = abs(d.x) / A + abs(d.y) / H - 1.0;
  float dist = f / sqrt(1.0 / (A * A) + 1.0 / (H * H));
  float e = 0.004;
  // (the edge moves in by its whole softness at the end, so even the finest strands are gone)
  float hole = max(smoothstep(0.0, e, e * q * q * q * q - dist), clamp(0.5 - side, 0.0, 1.0));

  vec4 img = vec4(0.0);
  if (hole < 1.0) {
    // the strands carry the image, lengthened with the sheet
    vec2 sp = vec2(p.x, p.y / Sy);
    if (horizontal) sp = sp.yx;
    img = getFromColor(clamp(sp / asp + 0.5, 0.0, 1.0));
    // the strands twist out of the sheet: the ones rising to the right face the light, the others turn away
    float facet = clamp(d.x * d.y / (0.25 * a * b + 1e-6), -1.0, 1.0);
    float rim = clamp(1.0 - dist / (0.25 * b + 1e-5), 0.0, 1.0);
    img.rgb *= 1.0 + shading * q * (0.35 * facet - 0.25 * rim);
    if (hole <= 0.0) return img;
  }
  vec4 bg = getToColor(uv);
  // the mesh casts a soft shadow next to the strands
  // (only within the sheet, not beside its waist)
  float sh = (1.0 - smoothstep(0.0, 0.25 * b + e, -dist)) * clamp(0.5 + side, 0.0, 1.0);
  bg.rgb *= 1.0 - 0.45 * shading * sh * (1.0 - q);
  return mix(img, bg, hole);
}
