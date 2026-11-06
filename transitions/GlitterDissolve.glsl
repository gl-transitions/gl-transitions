// Author: gre
// License: MIT
// Description: The image becomes a shimmering field of tiny diamond sequins that flip over in 3D at random moments, each lifting and tilting on its own axis and flashing a glint of light, and land on the incoming image
// Tags: tiles, flip, 3d, sparkle, dissolve

// @range(6, 60) Number of tiles stacked across the height of the frame
uniform float tiles; // = 20.0
// @param Hexagonal tiles instead of diamonds
uniform bool hexagons; // = false
// @range(0, 2) Strength of the glints the tiles catch as they turn
uniform float sparkle; // = 1.0
// @color Color of the glints, added as light
uniform vec3 glint; // = vec3(1.0, 0.97, 0.9)
// @range(0, 100) Changes the order and the axes of the flips (whole numbers)
uniform float seed; // = 0.0
// @color Color seen behind a tile while it is edge-on
uniform vec4 backColor; // = vec4(0.04, 0.04, 0.05, 1.0)

// share of the transition each tile takes to flip over
const float FLIP = 0.28;
// how much a tile grows as it lifts toward the viewer, halfway through its flip
const float LIFT = 0.3;
// width of the soft edge of the tiles, in tiles
const float EDGE = 0.04;
// the grid is shifted off the pixel centers, so that no pixel sits right on the border of two tiles
const vec2 SHIFT = vec2(0.37, 0.21);
const float PI = 3.14159265;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// folds uv back into 0..1, so the tiles on the border of the frame stay filled
vec2 mirrored(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

// how far the tile has flipped, 0 before it starts and 1 once it has landed
float flipOf(vec2 id) {
  float t = clamp((progress - hash12(id) * (1.0 - FLIP)) / FLIP, 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// the direction perpendicular to the axis the tile turns around
vec2 axisOf(vec2 id) {
  float a = 2.0 * PI * hash12(id + 41.7);
  return vec2(cos(a), sin(a));
}

// the point of the flat tile seen at offset s from its center, through the foreshortening and the lift
vec2 unproject(vec2 s, vec2 n, float f) {
  float c = abs(cos(PI * f));
  float along = dot(s, n);
  return (s + n * (along / max(c, 1e-4) - along)) / (1.0 + LIFT * sin(PI * f));
}

// 0.5 on the edges of a tile one unit tall: a diamond one unit wide, or a flat-top hexagon
float shape(vec2 v) {
  v = abs(v);
  return hexagons ? max(v.y, dot(v, vec2(0.8660254, 0.5))) : v.x + v.y;
}

// the id of the tile centered at center
vec2 idOf(vec2 center) {
  // the centers sit on multiples of (0.866, 0.5) for hexagons, of (0.5, 0.5) for diamonds
  vec2 grid = hexagons ? vec2(1.1547005, 2.0) : vec2(2.0);
  return floor(center * grid + 0.5) + vec2(13.0, 7.0) * floor(seed) + 3.0;
}

// how much of the flipping tile centered at center covers the point p, with an edge soft on screen
float coverOf(vec2 p, vec2 center) {
  vec2 id = idOf(center);
  float f = flipOf(id);
  if (f <= 0.0 || f >= 1.0) return 0.0;
  float z = sin(PI * f);
  // the tile is foreshortened by |cos| along its axis and grown by the lift
  float onScreen = (1.0 + LIFT * z) * max(abs(cos(PI * f)), 0.15);
  // the edge softens in as the tile starts turning, so that nothing pops
  float edge = EDGE * min(1.0, 4.0 * z) + 1e-4;
  return clamp((0.5 - shape(unproject(p - center, axisOf(id), f))) * onScreen / edge, 0.0, 1.0);
}

// the flipping tile centered at center, seen at the point p: shaded, with its glint
vec4 tileColor(vec2 p, vec2 center) {
  vec2 id = idOf(center);
  float f = flipOf(id);
  vec2 n = axisOf(id);
  float c = cos(PI * f);
  float z = sin(PI * f);
  vec2 s0 = unproject(p - center, n, f);
  vec2 suv = mirrored((center + s0 - SHIFT) / tiles / vec2(ratio, 1.0) + 0.5);
  vec4 col = c > 0.0 ? getFromColor(suv) : getToColor(suv);
  // the face turned to the viewer, slightly cupped like a sequin, lit from the top left
  vec3 nrm = normalize(vec3(n * z * (c < 0.0 ? -1.0 : 1.0) + 0.5 * s0, abs(c)));
  vec3 L = normalize(vec3(-0.3, 0.4, 1.0));
  float shade = 0.45 + 0.55 * clamp(dot(nrm, L) / L.z, 0.0, 1.6);
  // a glint where the face mirrors the light toward the viewer, and on the rim when edge-on
  vec3 H = normalize(vec3(-0.45, 0.55, 1.0));
  float spec = smoothstep(0.94, 0.995, dot(nrm, H)) * 2.0 + pow(1.0 - abs(c), 6.0) * 0.6;
  vec3 light = clamp(glint * sparkle * spec * z, 0.0, 1.0);
  vec3 base = clamp(col.rgb * mix(1.0, shade, z), 0.0, 1.0);
  return vec4(base + light - base * light, col.a);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  // in units where the tiles are one unit tall
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0) * tiles + SHIFT;
  // the center of the tile of the pixel
  vec2 home;
  if (hexagons) {
    vec2 s = vec2(1.7320508, 1.0);
    vec2 a = mod(p, s) - 0.5 * s;
    vec2 b = mod(p - 0.5 * s, s) - 0.5 * s;
    home = dot(a, a) < dot(b, b) ? p - a : p - b;
  } else {
    // a square grid turned by 45 degrees
    vec2 q = floor(vec2(p.x + p.y, p.y - p.x)) + 0.5;
    home = vec2(q.x - q.y, q.x + q.y) * 0.5;
  }

  // what lies under the flipping tiles: the image while the own tile rests, else the backing
  float fHome = flipOf(idOf(home));
  vec4 under = fHome <= 0.0 ? getFromColor(uv) : fHome >= 1.0 ? getToColor(uv) : backColor;

  // the two topmost flipping tiles at the pixel, among its own and the lifted neighbours
  // reaching over it: the higher a tile is in its flip, the closer it is to the viewer
  float z1 = -1.0;
  float z2 = -1.0;
  float cover1 = 0.0;
  float cover2 = 0.0;
  vec2 center1 = home;
  vec2 center2 = home;
  for (int k = 0; k < 9; k++) {
    float fk = float(k);
    vec2 off;
    if (hexagons) {
      if (k > 6) break;
      off = k == 0 ? vec2(0.0) : k < 3 ? vec2(0.0, fk * 2.0 - 3.0) : vec2(mod(fk, 2.0) * 1.7320508 - 0.8660254, fk < 5.0 ? -0.5 : 0.5);
    } else {
      vec2 o = vec2(mod(fk, 3.0) - 1.0, floor(fk / 3.0) - 1.0);
      off = vec2(o.x - o.y, o.x + o.y) * 0.5;
    }
    vec2 center = home + off;
    float cover = coverOf(p, center);
    if (cover <= 0.0) continue;
    float z = sin(PI * flipOf(idOf(center)));
    if (z > z1) {
      z2 = z1;
      cover2 = cover1;
      center2 = center1;
      z1 = z;
      cover1 = cover;
      center1 = center;
    } else if (z > z2) {
      z2 = z;
      cover2 = cover;
      center2 = center;
    }
  }
  if (z1 < 0.0) return under;
  vec4 c = under;
  if (z2 >= 0.0 && cover1 < 1.0) c = mix(c, tileColor(p, center2), cover2);
  return mix(c, tileColor(p, center1), cover1);
}
