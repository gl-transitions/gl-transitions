// Author: gre
// License: MIT
// Description: The incoming image arrives cut into a geometric poster of quarter discs, half discs, triangles and their complements: piece after piece swings in around a corner of its cell, a flat plate of color just ahead of it, and lands flat with a soft paper shadow
// Tags: geometric, shapes, collage, rotate, color

// @range(1, 5, 1) Number of cells along the short side of the frame, the long side gets as many as keep them about square
uniform int cells; // = 2
// @range(0, 1) How spread out in time the pieces arrive: 0 swings them all in together, 1 lands them one after another
uniform float stagger; // = 1.0
// @param Show a flat plate of color swinging in just ahead of each piece
uniform bool plates; // = true
// @color First plate color
uniform vec4 color1; // = vec4(0.89, 0.22, 0.17, 1.0)
// @color Second plate color
uniform vec4 color2; // = vec4(0.97, 0.77, 0.15, 1.0)
// @color Third plate color
uniform vec4 color3; // = vec4(0.14, 0.32, 0.66, 1.0)
// @range(0, 1) Darkness of the shadows the pieces cast while they swing in
uniform float shadow; // = 0.6

const float PI = 3.141592653589793;
// shortest duration of the swing of one layer, delay of a cell's second piece, lead of a plate over its piece
const float DUR = 0.24;
const float GAP = 0.07;
const float LEAD = 0.06;
// part of a swing after which a layer has turned into place, and only comes down flat onto the paper
const float SETTLE = 0.8;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.002;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// the cell's layout seen from its first piece: the local point turned by k quarter turns around the cell center
vec2 orient(vec2 l, float k) {
  vec2 c = l - 0.5;
  if (k < 0.5) return l;
  if (k < 1.5) return vec2(-c.y, c.x) + 0.5;
  if (k < 2.5) return 0.5 - c;
  return vec2(c.y, -c.x) + 0.5;
}

// the cell corner that orient(., k) maps to the corner (0, 0): the first piece's pivot
vec2 pivotCorner(float k) {
  if (k < 0.5) return vec2(0.0, 0.0);
  if (k < 1.5) return vec2(0.0, 1.0);
  if (k < 2.5) return vec2(1.0, 1.0);
  return vec2(1.0, 0.0);
}

// signed distance (in cell units) to the cell's first piece, negative inside; the second piece is its complement
float shapeDist(vec2 o, float type) {
  if (type < 0.5) return length(o) - 1.0;                  // quarter disc around the pivot
  if (type < 1.5) return length(o - vec2(0.5, 0.0)) - 0.5; // half disc on an edge
  return (o.x + o.y - 1.0) * 0.70710678;                    // triangle
}

// signed distance (in cell units) to a piece of a cell at the local point l, negative inside
float pieceDist(vec2 l, vec2 cell, float piece) {
  float k = floor(hash12(cell + 1.7) * 4.0);
  // cells side by side never share a shape
  float sd = shapeDist(orient(l, k), mod(cell.x + 2.0 * cell.y + 1.0, 3.0));
  return piece > 0.5 ? -sd : sd;
}

float boxDist(vec2 l) {
  return min(min(l.x, l.y), min(1.0 - l.x, 1.0 - l.y));
}

float easeOutCubic(float t) {
  float u = 1.0 - clamp(t, 0.0, 1.0);
  return 1.0 - u * u * u;
}

// how high a layer floats above the paper along its swing, 0 once landed
float lift(float t) {
  return 1.0 - smoothstep(0.3, 1.0, t);
}

// the time over which the cells start one after another, and the duration of a swing, which gets
// longer when the cells start closer together, so that the last piece always lands just before the end
float spread() {
  return (1.0 - DUR - GAP - LEAD - 0.02) * clamp(stagger, 0.0, 1.0);
}
float swing() {
  return 1.0 - GAP - LEAD - 0.02 - spread();
}

// when the first piece of a cell starts to swing in; the second one starts GAP later, and a plate LEAD before its piece
float startTime(vec2 cell, vec2 n) {
  float order = (cell.x + (n.y - 1.0 - cell.y)) / max(n.x + n.y - 2.0, 1.0);
  order = clamp(order * 0.75 + 0.25 * hash12(cell + 4.4), 0.0, 1.0);
  return LEAD + spread() * order;
}

// the local point in the cell of a swinging layer at its local time t (0 < t < 1), seen at the frame point p,
// and its scale
vec3 swingPoint(vec2 p, vec2 cell, vec2 cs, float piece, float t) {
  vec2 pc = pivotCorner(floor(hash12(cell + 1.7) * 4.0));
  // the first piece turns around its pivot corner, its complement around the opposite one
  vec2 piv = (cell + (piece < 0.5 ? pc : 1.0 - pc)) * cs;
  float sgn = hash12(cell + vec2(piece * 3.3, 5.2)) < 0.5 ? -1.0 : 1.0;
  // grows out of the corner while it swings a quarter turn into place, a bit bigger while it floats
  float s = smoothstep(0.0, 0.45, t) * (1.0 + 0.1 * lift(t));
  // the swing settles first, then the layer comes down flat onto the paper
  float a = sgn * 0.5 * PI * (1.0 - easeOutCubic(t / SETTLE));
  float ca = cos(a), sa = sin(a);
  vec2 d = p - piv;
  d = vec2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y) / max(s, 0.001);
  return vec3((piv + d) / cs - cell, s);
}

// the coverage of a swinging layer and its local point in the cell
vec3 layerCover(vec2 p, vec2 cell, vec2 cs, float piece, float t) {
  vec3 q = swingPoint(p, cell, cs, piece, t);
  if (q.z < 0.01) return vec3(0.0);
  float e = EDGE / (min(cs.x, cs.y) * q.z);
  float m = clamp(boxDist(q.xy) / e + 0.5, 0.0, 1.0) * clamp(-pieceDist(q.xy, cell, piece) / e + 0.5, 0.0, 1.0);
  return vec3(m, clamp(q.xy, 0.0, 1.0));
}

// the coverage of the soft shadow of a swinging layer: it falls down and to the right, further away the higher it floats
float layerShadow(vec2 p, vec2 cell, vec2 cs, float piece, float t) {
  float h = lift(t);
  vec3 q = swingPoint(p - vec2(0.07, -0.1) * h * cs.y, cell, cs, piece, t);
  if (q.z < 0.01) return 0.0;
  float soft = 0.02 + 0.05 * h;
  return h * (1.0 - smoothstep(-soft, soft, pieceDist(q.xy, cell, piece))) * smoothstep(-soft, soft, boxDist(q.xy));
}

vec4 plateColor(vec2 cell, float piece) {
  float c = mod(floor(hash12(cell * 1.3 + 0.7) * 3.0) + piece, 3.0);
  return c < 0.5 ? color1 : c < 1.5 ? color2 : color3;
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float kc = float(cells < 1 ? 1 : cells);
  vec2 n = ratio >= 1.0 ? vec2(max(1.0, floor(ratio * kc + 0.5)), kc) : vec2(kc, max(1.0, floor(kc / ratio + 0.5)));
  vec2 cs = vec2(ratio, 1.0) / n;
  vec2 p = uv * vec2(ratio, 1.0);
  vec2 cell0 = floor(p / cs);
  float sw = swing();

  // the paper: the outgoing image, where the pieces that have landed show the incoming one. They lie flat side by side
  // and tile the frame exactly, with hard cell edges and anti-aliased edges between the two pieces of a cell
  vec2 l0 = p / cs - cell0;
  float t00 = startTime(cell0, n);
  float sd0 = pieceDist(l0, cell0, 0.0);
  float e0 = EDGE / min(cs.x, cs.y);
  float landed = (progress >= t00 + sw ? clamp(-sd0 / e0 + 0.5, 0.0, 1.0) : 0.0)
    + (progress >= t00 + GAP + sw ? clamp(sd0 / e0 + 0.5, 0.0, 1.0) : 0.0);
  // the layers still in the air, and the plates not yet covered by their pieces: the top one at p and the one
  // under it by start time, as (start, coverage, plate, piece) and (cell, local point)
  vec4 top = vec4(-1.0, 0.0, 0.0, 0.0);
  vec4 topPos = vec4(0.0);
  vec4 und = vec4(-1.0, 0.0, 0.0, 0.0);
  vec4 undPos = vec4(0.0);
  for (int dy = -1; dy <= 1; dy++) {
    for (int dx = -1; dx <= 1; dx++) {
      vec2 cell = cell0 + vec2(float(dx), float(dy));
      if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= n.x || cell.y >= n.y) continue;
      float tc = startTime(cell, n);
      for (int pc = 0; pc < 2; pc++) {
        float piece = float(pc);
        float t0 = tc + GAP * piece;
        // how far the piece is in its swing
        float tp = (progress - t0) / sw;
        for (int ly = 0; ly < 2; ly++) {
          float isPlate = ly == 0 ? 1.0 : 0.0;
          if (isPlate > 0.5 && !plates) continue;
          float ts = t0 - LEAD * isPlate;
          float t = (progress - ts) / sw;
          // a landed piece is part of the paper, and its plate fades out under it once it has turned into place
          if (t <= 0.0 || tp >= 1.0 || (isPlate > 0.5 && tp >= SETTLE)) continue;
          vec3 L = layerCover(p, cell, cs, piece, min(t, 1.0));
          if (isPlate > 0.5) L.x *= 1.0 - smoothstep(SETTLE - 0.1, SETTLE, tp);
          if (L.x <= 0.0) continue;
          vec4 cur = vec4(ts, L.x, isPlate, piece);
          vec4 curPos = vec4(cell, L.yz);
          if (ts > top.x) {
            und = top;
            undPos = topPos;
            top = cur;
            topPos = curPos;
          } else if (ts > und.x) {
            und = cur;
            undPos = curPos;
          }
        }
      }
    }
  }
  // a piece coming down next to its landed complement does not overlap it along their common edge: their coverages add up
  if (top.z < 0.5 && und.x < 0.0 && topPos.x == cell0.x && topPos.y == cell0.y) {
    landed = top.y < 1.0 ? landed / (1.0 - top.y) : 1.0;
  }
  vec4 c = mix(premultiplied(getFromColor(uv)), premultiplied(getToColor(uv)), clamp(landed, 0.0, 1.0));
  if (und.x >= 0.0) {
    vec4 uc = und.z > 0.5 ? plateColor(undPos.xy, und.w) : getToColor((undPos.xy + undPos.zw) * cs / vec2(ratio, 1.0));
    c = mix(c, premultiplied(uc), und.y);
  }
  if (top.x >= 0.0) {
    vec4 tc = top.z > 0.5 ? plateColor(topPos.xy, top.w) : getToColor((topPos.xy + topPos.zw) * cs / vec2(ratio, 1.0));
    c = mix(c, premultiplied(tc), top.y);
  }

  // the soft shadows of the layers floating above the top one
  float sh = 0.0;
  if (shadow > 0.0) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        vec2 cell = cell0 + vec2(float(dx), float(dy));
        if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= n.x || cell.y >= n.y) continue;
        float tc = startTime(cell, n);
        for (int pc = 0; pc < 2; pc++) {
          float piece = float(pc);
          float t0 = tc + GAP * piece;
          float tp = (progress - t0) / sw;
          for (int ly = 0; ly < 2; ly++) {
            float isPlate = ly == 0 ? 1.0 : 0.0;
            if (isPlate > 0.5 && (!plates || tp >= SETTLE)) continue;
            float ts = t0 - LEAD * isPlate;
            float t = (progress - ts) / sw;
            if (ts <= top.x || t <= 0.0 || t >= 1.0) continue;
            sh = max(sh, layerShadow(p, cell, cs, piece, t));
          }
        }
      }
    }
  }
  c.rgb *= 1.0 - 0.7 * clamp(shadow, 0.0, 1.0) * sh;
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
