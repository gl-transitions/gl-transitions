// Author: gre
// License: MIT
// Description: The image is cut into squares that turn in alternate directions while staying hinged at their corners, so the sheet opens into a checkerboard of diamonds showing the incoming image; those diamonds then turn back into place and close the sheet
// Tags: grid, tiles, geometric, rotate

// @range(1, 20, 1) Number of squares across the height of the frame
uniform int cells; // = 5
// @range(0, 1) Strength of the bevel on the turning squares and of the soft shadow they cast into the gaps
uniform float shading; // = 0.6
// @range(0, 1) How much the view zooms out to keep the opening sheet in frame (0: the sheet grows past the frame edges)
uniform float zoom; // = 0.5

const float PI = 3.141592653589793;
// half width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0012;

// turns v clockwise by the angle whose cosine and sine are cs
vec2 rot(vec2 v, vec2 cs) {
  return vec2(cs.x * v.x + cs.y * v.y, -cs.y * v.x + cs.x * v.y);
}

// one of the 4 lattice nodes around a point
vec2 node(float i) {
  return vec2(mod(i, 2.0), floor(i * 0.5));
}

// alternate squares turn in opposite directions
float parity(vec2 n) {
  return mod(n.x + n.y, 2.0) < 0.5 ? 1.0 : -1.0;
}

// The square nearest to w among the 4 around the cell g of a hinged lattice of unit squares
// centered at (n + off) * spacing, each turned by +-the angle of cs:
// returns its local coordinates, the signed distance to it and its node index.
vec4 nearest(vec2 w, vec2 g, float spacing, vec2 off, vec2 cs) {
  vec4 best = vec4(0.0, 0.0, 1e5, 0.0);
  for (int i = 0; i < 4; i++) {
    vec2 n = g + node(float(i));
    vec2 l = rot(w - (n + off) * spacing, vec2(cs.x, parity(n) * cs.y));
    vec2 q = abs(l) - 0.5;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    if (d < best.z) best = vec4(l, d, float(i));
  }
  return best;
}

// The gap of that lattice around w: a rhombus of unit sides centered at a node of the other
// lattice, with half diagonals cs.x and cs.y. Returns the local coordinates of the piece of the
// other image it shows, held at 45 degrees, and its node index.
vec3 gap(vec2 w, vec2 g, float spacing, vec2 off, vec2 cs) {
  vec3 best = vec3(0.0, 0.0, 0.0);
  float r = 1e5;
  for (int i = 0; i < 4; i++) {
    vec2 n = g + node(float(i));
    vec2 v = w - (n + off) * spacing;
    vec2 h = parity(n) > 0.0 ? cs.yx : cs;
    // inside the rhombus when |v.x| / h.x + |v.y| / h.y < 1, scaled by h.x * h.y to avoid dividing by 0
    float ri = abs(v.x) * h.y + abs(v.y) * h.x;
    if (ri < r) {
      r = ri;
      best = vec3(rot(v, vec2(0.7071068, parity(n) * 0.7071068)), float(i));
    }
  }
  return best;
}

// lattice coordinates (in squares, centered) to a mirrored texture uv that stays in the frame
vec2 toUV(vec2 c, float n) {
  vec2 uv = c / (n * vec2(ratio, 1.0)) + 0.5;
  return abs(mod(uv + 1.0, 2.0) - 1.0);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float n = max(float(cells), 1.0);
  float e = progress * progress * (3.0 - 2.0 * progress);
  float a = 0.5 * PI * e;
  // turn of the squares in front: 0 to 45 degrees for the outgoing ones, then 45 to 0 for the incoming ones
  float th = min(a, 0.5 * PI - a);
  // the hinged lattice spreads while it opens
  vec2 cs = vec2(cos(th), sin(th));
  float spacing = cs.x + cs.y;
  float scale = n * mix(1.0, spacing, clamp(zoom, 0.0, 1.0));
  vec2 w = (uv - 0.5) * vec2(ratio, 1.0) * scale;
  bool first = a < 0.25 * PI;
  vec2 offF = first ? vec2(0.0) : vec2(0.5);
  vec2 offB = vec2(0.5) - offF;
  vec2 gF = floor(w / spacing - offF);
  vec2 gB = floor(w / spacing - offB);
  // front: the turning squares; back: the pieces of the other image held at 45 degrees in the gaps
  vec4 f = nearest(w, gF, spacing, offF, cs);
  vec3 b = gap(w, gB, spacing, offB, cs);
  vec2 nf = gF + node(f.w);
  vec2 nb = gB + node(b.z);
  vec2 uvF = toUV(nf + offF + f.xy, n);
  vec2 uvB = toUV(nb + offB + b.xy, n);
  vec4 colF = first ? getFromColor(uvF) : getToColor(uvF);
  vec4 colB = first ? getToColor(uvB) : getFromColor(uvB);

  // relief: none when the sheet is closed or fully open, strongest in between
  float depth = clamp(shading, 0.0, 1.0) * sin(4.0 * th);
  // soft shadow cast by the front squares toward the lower right
  if (depth > 0.0) {
    vec2 ws = w - vec2(0.12, -0.12) * depth;
    vec4 sh = nearest(ws, floor(ws / spacing - offF), spacing, offF, cs);
    colB.rgb *= 1.0 - 0.75 * depth * (1.0 - smoothstep(-0.12, 0.25, sh.z));
  }
  // bevel lit from the upper left, along each square's nearest side
  vec2 side = abs(f.x) > abs(f.y) ? vec2(sign(f.x), 0.0) : vec2(0.0, sign(f.y));
  float facing = dot(rot(side, vec2(cs.x, -parity(nf) * cs.y)), vec2(-0.7071, 0.7071));
  float rim = smoothstep(-0.07, -0.01, f.z);
  colF.rgb *= 1.0 + 0.35 * depth * rim * facing;

  // anti-aliased edges; the squares overlap a little to hide the gaps until they are a few pixels wide
  float aa = EDGE * scale;
  float seal = aa * (1.0 - smoothstep(0.0, 3.0 * aa, cs.y));
  float cover = 1.0 - smoothstep(-aa, aa, f.z - seal);
  return mix(colB, colF, cover);
}
