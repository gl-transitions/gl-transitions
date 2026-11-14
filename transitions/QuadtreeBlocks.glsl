// Author: gre
// License: MIT
// Description: The outgoing image breaks into a quadtree of flat color blocks, small where it is detailed and large where it is plain; the blocks merge into a few big squares that change color one by one, then split again, finer and finer, into the incoming image
// Tags: blocks, pixelate, color, grid, motion-graphics

// @range(0, 0.2) How different the colors inside a block may be before it splits (larger gives bigger blocks)
uniform float tolerance; // = 0.05
// @range(0, 1) Darkness of the thin seams between the blocks
uniform float seams; // = 0.35

// number of levels: the smallest blocks are 1/64 of the largest ones
const int LEVELS = 7;
// width of the anti-aliased edges and of the seams, as a part of the frame's height
const float AA = 0.0015;
const float SEAM = 0.0025;

vec4 img(vec2 P, bool incoming) {
  vec2 uv = vec2(P.x / ratio, P.y);
  return incoming ? getToColor(uv) : getFromColor(uv);
}

// 1 on a seam between the blocks of size s, 0 elsewhere; the frame's border has none
float seamLine(vec2 P, vec2 s) {
  vec2 frame = vec2(ratio, 1.0);
  vec2 lo = floor(P / s) * s;
  vec2 hi = lo + s;
  vec2 q = vec2(1.0);
  if (lo.x > AA) q.x = P.x - lo.x;
  if (hi.x < frame.x - AA) q.x = min(q.x, hi.x - P.x);
  if (lo.y > AA) q.y = P.y - lo.y;
  if (hi.y < frame.y - AA) q.y = min(q.y, hi.y - P.y);
  return 1.0 - smoothstep(SEAM - AA, SEAM + AA, min(q.x, q.y));
}

// the quadtree of one image around P, the largest blocks of size s0: each block shows the mean of
// its four quadrants and splits while their colors spread more than thr, down to depth dmax. A block
// that just reaches the threshold or the depth is half split: it fades into its four children, so
// the blocks never pop. Thin dark seams, faded in by seamFade, line the blocks
vec4 tree(vec2 P, vec2 s0, bool incoming, float thr, float dmax, float seamFade) {
  vec2 s = s0;
  vec4 col = vec4(0.0);
  // the weight of the current level in the result: how much the blocks above it have split
  float acc = 1.0;
  float seam = 0.0;
  for (int l = 0; l < LEVELS; l++) {
    vec2 c = (floor(P / s) + 0.5) * s;
    vec2 h = 0.25 * s;
    vec4 a = img(c - h, incoming);
    vec4 b = img(c + vec2(h.x, -h.y), incoming);
    vec4 d = img(c + vec2(-h.x, h.y), incoming);
    vec4 e = img(c + h, incoming);
    vec4 mean = 0.25 * (a + b + d + e);
    vec4 v = abs(a - mean) + abs(b - mean) + abs(d - mean) + abs(e - mean);
    float spread = dot(v, vec4(0.0625));
    // the seams of the smallest blocks are fainter, so they never cover the picture with a dark mesh
    seam = max(seam, acc * smoothstep(0.008, 0.04, s.y) * seamLine(P, s));
    float split = smoothstep(thr, 1.35 * thr + 0.003, spread) * smoothstep(0.2, 0.8, dmax - float(l));
    if (l == LEVELS - 1) split = 0.0;
    col += acc * (1.0 - split) * mean;
    acc *= split;
    if (acc <= 0.0) break;
    s *= 0.5;
  }
  col.rgb *= 1.0 - seams * seamFade * seam;
  return col;
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  // kept inside the frame, so the right and top edges stay in the last blocks
  vec2 P = clamp(vec2(uv.x * ratio, uv.y), vec2(0.0), vec2(ratio, 1.0) - 1e-4);
  // u: 0 at the ends (the real images), 1 in the middle (the biggest blocks)
  float u = 1.0 - abs(2.0 * progress - 1.0);
  float coarse = mix(u, u * u * (3.0 - 2.0 * u), 0.5);
  float thr = tolerance * (0.08 + 4.0 * coarse * coarse);
  float dmax = float(LEVELS) * (1.0 - coarse) + 0.2;
  float seamFade = smoothstep(0.0, 0.25, u);

  // the largest blocks: nearly square, two of them across the frame's shorter side
  vec2 s0 = ratio >= 1.0
    ? vec2(ratio / floor(2.0 * ratio + 0.5), 0.5)
    : vec2(0.5 * ratio, 1.0 / floor(2.0 / ratio + 0.5));
  // around the middle, each big block changes from the outgoing colors to the incoming ones at its
  // own moment, in a quick fade
  float t = (progress - 0.4) / 0.2;
  // the blocks take turns in a shuffled order, evenly spread over the time of the change
  vec2 cell = floor(P / s0);
  float h = fract((cell.y * floor(ratio / s0.x + 0.5) + cell.x) * 0.618034 + 0.31);
  float flip = smoothstep(0.75 * h, 0.75 * h + 0.25, t);
  vec4 col;
  if (flip <= 0.0) {
    col = tree(P, s0, false, thr, dmax, seamFade);
  } else if (flip >= 1.0) {
    col = tree(P, s0, true, thr, dmax, seamFade);
  } else {
    col = mix(tree(P, s0, false, thr, dmax, seamFade), tree(P, s0, true, thr, dmax, seamFade), flip);
  }
  // the real image shows through the finest blocks at both ends
  vec4 real = progress < 0.5 ? getFromColor(uv) : getToColor(uv);
  return mix(real, col, smoothstep(0.0, 0.18, u));
}
