// Author: gre
// License: MIT
// Description: The image splits into hexagons that spin and shrink away in a wave from the center, uncovering the incoming image
// Tags: hexagon, tiles, rotate, radial

// @range(2, 30) Number of hexagons across the shorter side
uniform float size; // = 6.0

// Distance to the center of a pointy-top hexagon, 0.5 on the edges of a cell
float hexDist(vec2 p) {
  p = abs(p);
  return max(p.x, dot(p, vec2(0.5, 0.8660254)));
}

mat2 rotation(float a) {
  return mat2(cos(a), sin(a), -sin(a), cos(a));
}

// Coverage of a hexagon turned by a and scaled by s inside its cell, with soft edges of width e
// (unturned at s = 1, it covers its whole cell)
float hexMask(vec2 local, float s, float a, float e) {
  float r = (0.52 + e) * s;
  return 1.0 - smoothstep(r - e, r, hexDist(rotation(-a) * local));
}

// Where the image is sampled, for a point of a hexagon turned by a and scaled by s
vec2 hexUv(vec2 uv, vec2 local, vec2 cellToUv, float s, float a) {
  return uv + cellToUv * (rotation(-a) * local / max(s, 0.001) - local);
}

vec4 transition(vec2 uv) {
  // nearest hexagon center, on two interleaved rectangular grids (centers 1 apart)
  vec2 toCells = vec2(ratio, 1.0) * size / min(ratio, 1.0);
  vec2 p = (uv - 0.5) * toCells;
  const vec2 grid = vec2(1.0, 1.7320508);
  vec2 a = (floor(p / grid) + 0.5) * grid;
  vec2 b = (floor((p - 0.5 * grid) / grid) + 1.0) * grid;
  vec2 center = dot(p - a, p - a) < dot(p - b, p - b) ? a : b;
  vec2 local = p - center;

  // each hexagon starts later the further it is from the center
  float d = min(length(center / toCells * vec2(ratio, 1.0)) / (0.5 * length(vec2(ratio, 1.0))), 1.0);
  float t = clamp((progress - 0.6 * d) / 0.4, 0.0, 1.0);

  // the outgoing hexagon spins (opening gaps at the corners of its cell), shrinks away and darkens,
  // casting a soft shadow on the incoming image
  float s = 1.0 - smoothstep(0.1, 1.0, t);
  float turn = 1.8 * t * (2.0 - t);
  vec4 fromTile = getFromColor(hexUv(uv, local, 1.0 / toCells, s, turn));
  fromTile.rgb *= 1.0 - 0.3 * t;
  vec4 below = getToColor(uv);
  below.rgb *= 1.0 - 0.5 * hexMask(local - vec2(0.06, -0.08) * s, s, turn, 0.2);
  return mix(below, fromTile, hexMask(local, s, turn, 0.03));
}
