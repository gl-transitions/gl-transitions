// License: MIT
// Author: TimDonselaar
// Description: The image splits into a grid of cards that lift apart and turn over in perspective one after another, each one showing its part of the incoming image on its back
// Tags: grid, tiles, flip, 3d
// ported by gre from https://gist.github.com/TimDonselaar/9bcd1c4b5934ba60087bdb55c2ea92e5

// @param Number of tiles (columns, rows)
uniform ivec2 size; // = ivec2(4)
// @range(0, 0.4) Part of the transition at the start and at the end during which the gaps between the tiles open and close
uniform float pause; // = 0.1
// @range(0, 0.4) Width of the gaps between the tiles, as a part of a tile's shorter side
uniform float dividerWidth; // = 0.05
// @color Color behind the tiles
uniform vec4 bgcolor; // = vec4(0.0, 0.0, 0.0, 1.0)
// @range(0, 1) How much the order of the flips is shuffled, from a diagonal wave across the grid to random
uniform float randomness; // = 0.1

const float PI = 3.141592653589793;
// width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0012;
// distance of the eye from each tile, in tile sizes
const float EYE = 2.2;
// part of the flips during which the last tile waits for its turn
const float STAGGER = 0.55;
// light direction (x, y over z): from the upper left, in front of the frame
const vec2 LIGHT = vec2(-0.45, 0.3);

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// eased turn: smooth start and landing, without lingering at either end
float easeInOut(float t) {
  return mix(t, t * t * (3.0 - 2.0 * t), 0.7);
}

// time the gaps take to open and to close
float pausePart() {
  return clamp(pause, 0.05, 0.4);
}

// the turn of a tile, 0 showing the outgoing image to 1 showing the incoming one,
// at q the progress of the flips and with stagger the delay of the last tile
float flipTime(vec2 cell, vec2 grid, float q, float stagger) {
  // a diagonal wave from the top left corner, shuffled by randomness
  float wave = (cell.x + (grid.y - 1.0 - cell.y)) / max(grid.x + grid.y - 2.0, 1.0);
  float order = mix(wave, hash12(cell + 7.31), clamp(randomness, 0.0, 1.0));
  return easeInOut(clamp((q - order * stagger) / (1.0 - stagger), 0.0, 1.0));
}

// how open the gaps are: they open at the start and close at the end
float gapAmount() {
  float pp = pausePart();
  return smoothstep(0.0, pp, progress) * (1.0 - smoothstep(1.0 - pp, 1.0, progress));
}

// coverage of a signed distance (positive inside) with an edge of width e
float aa(float d, float e) {
  return clamp(d / max(2.0 * e, 1e-6) + 0.5, 0.0, 1.0);
}

float boxShadow(vec2 p, vec2 halfSize, float blur) {
  vec2 d = abs(p) - halfSize;
  float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
  return 1.0 - smoothstep(-blur, blur, dist);
}

vec4 transition(vec2 uv) {
  vec2 grid = max(vec2(size), 1.0);
  vec2 frame = vec2(ratio, 1.0);
  vec2 tileSize = frame / grid;
  vec2 cell = clamp(floor(uv * grid), vec2(0.0), grid - 1.0);
  vec2 pos = uv * frame;
  float gapOpen = gapAmount();
  float minSide = min(tileSize.x, tileSize.y);
  float gap = clamp(dividerWidth, 0.0, 0.4) * minSide * gapOpen;
  vec2 halfTile = 0.5 * tileSize - gap;
  float eye = EYE * max(tileSize.x, tileSize.y);
  // the flips start while the gaps finish opening, and end while they start closing
  float pp = 0.6 * pausePart();
  float q = clamp((progress - pp) / (1.0 - 2.0 * pp), 0.0, 1.0);
  // a single tile takes all the time to turn
  float stagger = grid.x * grid.y > 1.5 ? STAGGER : 0.0;

  // the two nearest layers of the tiles that cover this point
  vec4 c1 = vec4(0.0);
  vec4 c2 = vec4(0.0);
  float m1 = 0.0;
  float m2 = 0.0;
  float z1 = 1e9;
  float z2 = 1e9;
  bool rest1 = true;
  bool rest2 = true;
  float shadowBg = 0.0;
  float shadowFlip = 0.0;

  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 nc = cell + vec2(float(i), float(j));
      if (nc.x < 0.0 || nc.y < 0.0 || nc.x > grid.x - 1.0 || nc.y > grid.y - 1.0) continue;
      float t = flipTime(nc, grid, q, stagger);
      float a = PI * t;
      float ca = cos(a);
      float sa = sin(a);
      bool rest = t <= 0.0 || t >= 1.0;
      if (rest) {
        ca = t <= 0.0 ? 1.0 : -1.0;
        sa = 0.0;
      }
      vec2 center = (nc + 0.5) * tileSize;
      vec2 q = pos - center;

      // shadows on the background: the tiles float a little above it, and higher while they turn
      float lift = 0.05 * gapOpen * minSide + 0.35 * halfTile.x * sa;
      vec2 shOffset = -LIGHT * lift;
      vec2 shHalf = vec2(halfTile.x * abs(ca) + 0.5 * lift, halfTile.y);
      float sh = boxShadow(q - shOffset, shHalf, 0.01 * minSide + 0.5 * lift);
      shadowBg = 1.0 - (1.0 - shadowBg) * (1.0 - 0.45 * gapOpen * sh);
      shadowFlip = max(shadowFlip, 0.45 * sa * sa * sh);

      // ray from the eye in front of the tile's center, through this point, to the turned tile
      // the tile turns around its vertical axis: its local x axis is (ca, 0, -sa), its normal (sa, 0, ca)
      float den = eye * ca - q.x * sa;
      if (abs(den) < 1e-6) continue;
      float s = eye * ca / den;
      if (s <= 0.0) continue;
      vec3 hit = vec3(s * q.x, s * q.y, eye * (1.0 - s));
      float u = hit.x * ca - hit.z * sa;
      // the edges seen on screen, to anti-alias them
      float xa = halfTile.x * ca * eye / (eye + halfTile.x * sa);
      float xb = -halfTile.x * ca * eye / (eye - halfTile.x * sa);
      float dx = min(q.x - min(xa, xb), max(xa, xb) - q.x);
      float dy = (halfTile.y - abs(hit.y)) / s;
      // soft edges, except where the tiles touch each other
      float e = max(min(EDGE, gap), EDGE * min(8.0 * sa, 1.0));
      float m = aa(min(dx, dy), e);
      if (m <= 0.0) continue;

      // the front shows the outgoing image, the back the incoming one, seen from behind
      bool front = ca > 0.0;
      vec2 src = (center + vec2(front ? u : -u, hit.y)) / frame;
      vec4 col = front ? getFromColor(src) : getToColor(src);
      if (!rest) {
        // lit from the upper left: the turning side facing the light brightens a little, the other darkens
        float nx = front ? sa : -sa;
        float lit = abs(ca) + nx * LIGHT.x;
        col.rgb *= mix(0.35, 1.0, clamp(lit, 0.0, 1.0)) + 0.25 * max(lit - 1.0, 0.0);
        // a thin bright rim on the edges of the turning card
        col.rgb += 0.12 * sa * (1.0 - smoothstep(0.0, 3.0 * EDGE, min(dx, dy)));
      }

      if (s < z1) {
        c2 = c1; m2 = m1; z2 = z1; rest2 = rest1;
        c1 = col; m1 = m; z1 = s; rest1 = rest;
      } else if (s < z2) {
        c2 = col; m2 = m; z2 = s; rest2 = rest;
      }
    }
  }

  // the flipping tiles cast their shadows on the background and on the tiles lying still
  vec4 color = bgcolor;
  color.rgb *= 1.0 - clamp(max(shadowBg, shadowFlip), 0.0, 1.0);
  if (rest2) c2.rgb *= 1.0 - shadowFlip;
  if (rest1) c1.rgb *= 1.0 - shadowFlip;
  color = mix(color, c2, m2);
  color = mix(color, c1, m1);
  return color;
}
