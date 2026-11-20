// Author: gre
// License: MIT
// Description: The camera pulls back and the outgoing image turns out to be one tile of a curved mosaic on a hyperbolic plane, six tiles meeting at every corner and shrinking endlessly toward a round rim, alternating between the two images; the mosaic glides one tile over and the camera pushes into the incoming image
// Tags: hyperbolic, tiling, mosaic, geometry, math

// @range(0, 1) Darkness of the joints between tiles
uniform float joints; // = 0.6

// {4,6} tiling, even so the two images alternate everywhere: Klein half-side of the central square, 1/sqrt(3)
const float C = 0.57735;
// Poincare half-side at a corner, so the picture never folds back inside a tile
const float PK = 0.36603;
// rapidity of the glide to the next tile's center, twice the inradius A
const float A = 0.65848;

float ease(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

vec3 boost(vec3 v, float r) {
  float e = exp(r), ch = 0.5 * (e + 1.0 / e), sh = 0.5 * (e - 1.0 / e);
  return vec3(v.x * ch + v.z * sh, v.y, v.x * sh + v.z * ch);
}

vec4 transition(vec2 uv) {
  float t = progress;
  float w = ease(t / 0.4) * ease((1.0 - t) / 0.4);
  float g = 2.0 * A * ease((t - 0.25) / 0.5);

  vec2 s = (uv - 0.5) * vec2(ratio, 1.0);
  // the rim passes just outside the frame corners
  vec2 p = s / (0.51 * length(vec2(ratio, 1.0)));
  // blended in the conformal Poincare model so tiles keep their shape while the camera moves
  vec2 k0 = (uv - 0.5) * 2.0 * C;
  vec2 pz = mix(k0 / (1.0 + sqrt(1.0 - dot(k0, k0))), p, w);

  // past halfway, glide back from the next tile mirrored onto this one: the same map, but the
  // frame edge then never lands on a wall at progress 1, whatever the float precision
  bool past = g > A;
  vec3 v = boost(vec3(2.0 * pz, 1.0 + dot(pz, pz)), past ? g - 2.0 * A : g);
  if (past) v.x = -v.x;

  // P accumulates the reflections, to find each tile's orientation
  mat3 P = mat3(1.0);
  float n = past ? 1.0 : 0.0;
  for (int i = 0; i < 24; i++) {
    vec2 k = v.xy / v.z;
    vec3 wall;
    if (k.x > C) wall = vec3(1.0, 0.0, C);
    else if (k.x < -C) wall = vec3(1.0, 0.0, -C);
    else if (k.y > C) wall = vec3(0.0, 1.0, C);
    else if (k.y < -C) wall = vec3(0.0, 1.0, -C);
    else break;
    // Minkowski reflection, <a, b> = a.x b.x + a.y b.y - a.z b.z
    vec3 jw = vec3(wall.xy, -wall.z) * (2.0 / (1.0 - C * C));
    v -= dot(v, jw) * wall;
    vec3 pw = P * wall;
    P -= mat3(pw * jw.x, pw * jw.y, pw * jw.z);
    n += 1.0;
  }
  vec2 k = v.xy / v.z;

  // turn each tile upright by quarter turns, judged in the view at mid-glide so a tile never flips while it moves
  vec3 o = boost(P * vec3(0.0, 0.0, 1.0), -A);
  vec3 ox = boost(P * vec3(0.1, 0.0, 1.0), -A);
  vec3 oy = boost(P * vec3(0.0, 0.1, 1.0), -A);
  vec2 ex = ox.xy / ox.z - o.xy / o.z;
  vec2 ey = oy.xy / oy.z - o.xy / o.z;
  if (past) { ex.x = -ex.x; ey.x = -ey.x; }
  if (ex.x * ey.y - ex.y * ey.x < 0.0) { k.x = -k.x; ex = -ex; }
  // comparisons rather than atan, whose handling of -0.0 differs between GPUs
  if (abs(ex.x) >= abs(ex.y)) { if (ex.x < 0.0) k = -k; }
  else if (ex.y > 0.0) k = vec2(-k.y, k.x);
  else k = vec2(k.y, -k.x);

  vec2 pk = k / (1.0 + sqrt(max(1.0 - dot(k, k), 0.0)));
  // conformal and aspect-correct (center crop) inside the mosaic, the full frame at both ends
  vec2 crop = vec2(min(1.0 / ratio, 1.0), min(ratio, 1.0));
  vec2 q = clamp(0.5 + mix(k / C, pk / PK, w) * 0.5 * mix(vec2(1.0), crop, w), 0.0, 1.0);
  vec4 c = mod(n, 2.0) > 0.5 ? getToColor(q) : getFromColor(q);

  vec2 e = 1.0 - abs(k) / C;
  float edge = 0.5 * min(e.x, e.y);
  // joints fade out where tiles shrink below a few pixels toward the rim
  float j = joints * w * smoothstep(0.02, 0.2, 1.0 - dot(pz, pz));
  c.rgb *= 1.0 - j * (1.0 - smoothstep(0.0, 0.03, edge));
  c.rgb *= 1.0 - w * smoothstep(0.8, 1.0, length(p));
  return c;
}
