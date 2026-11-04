// Author: gre
// License: MIT
// Description: The frame is cut into a grid of blocks that slide out one after another in a staggered cascade, some of them shrinking as they go, while the blocks of the incoming image slide in behind them to take their place
// Tags: slide, blocks, grid, directional, zoom

// @param Number of blocks (columns, rows), at most 40 along the direction
uniform ivec2 grid; // = ivec2(5, 4)
// @param Direction the blocks slide toward (rounded to the nearest axis)
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0, 0.95) Share of the transition over which the blocks set off one after another (0 slides them all together)
uniform float stagger; // = 0.6
// @range(0, 0.9) How much the zooming blocks shrink on their way, as a share of their size
uniform float zoom; // = 0.35
// @color Color seen in the gaps between the blocks
uniform vec4 background; // = vec4(0.0, 0.0, 0.0, 1.0)

// blocks per strip, at most
const int MAX_BLOCKS = 40;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  bool vertical = abs(direction.y) > abs(direction.x);
  bool backward = vertical ? direction.y < 0.0 : direction.x < 0.0;
  vec2 g = max(vec2(grid), 1.0);
  // a: position along the motion, toward which the blocks slide, b: across it
  float a = vertical ? uv.y : uv.x;
  float b = vertical ? uv.x : uv.y;
  if (backward) a = 1.0 - a;
  float n = min(vertical ? g.y : g.x, float(MAX_BLOCKS));
  float strips = vertical ? g.x : g.y;
  // every block of a strip slides along it, so a point can only show a block of its own strip
  float r = min(floor(b * strips), strips - 1.0);
  // the strips set off one after another, from the top (or the left)
  float rowOrder = strips > 1.0 ? (vertical ? r : strips - 1.0 - r) / (strips - 1.0) : 0.0;
  float st = clamp(stagger, 0.0, 0.95);
  float z = clamp(zoom, 0.0, 0.9);
  // in blocks
  float an = a * n;
  float bn = b * strips - r;

  // the incoming blocks follow the last outgoing block to leave, the rear one: they all
  // stay behind it, so no block ever overlaps another, and each one gets closer to the
  // block ahead of it until they all arrive together
  float rear = clamp((progress - st * mix(rowOrder, 1.0, 0.2)) / (1.0 - st), 0.0, 1.0);
  rear = rear * rear * (3.0 - 2.0 * rear);

  for (int k = 0; k < MAX_BLOCKS; k++) {
    float i = float(k);
    if (i >= n) break;
    // the block at the front sets off first, so that the outgoing blocks move apart
    float order = mix(rowOrder, n > 1.0 ? (n - 1.0 - i) / (n - 1.0) : 0.0, 0.2);
    float p = clamp((progress - st * order) / (1.0 - st), 0.0, 1.0);
    p = p * p * (3.0 - 2.0 * p);
    float pin = max(0.0, 1.0 - (1.0 - rear) * (1.0 + (n - 1.0 - i) / n));
    // about half of the blocks shrink as they leave, and their incoming blocks grow as they come
    float zi = hash(vec2(i, r) + 3.7) < 0.5 ? z : 0.0;
    // position in the block, from its corner, for the outgoing block (xy), which travels the
    // frame's length to leave it, and the incoming one (zw), from one length behind; at rest,
    // the blocks tile the frame exactly
    float sFrom = 1.0 - zi * p * p;
    float sTo = 1.0 - zi * (1.0 - pin) * (1.0 - pin);
    vec4 l = vec4(
      (an - i - p * n - 0.5 * (1.0 - sFrom)) / sFrom,
      (bn - 0.5 * (1.0 - sFrom)) / sFrom,
      (an - i - (pin - 1.0) * n - 0.5 * (1.0 - sTo)) / sTo,
      (bn - 0.5 * (1.0 - sTo)) / sTo);
    bool inFrom = all(greaterThanEqual(l.xy, vec2(0.0))) && all(lessThan(l.xy, vec2(1.0)));
    bool inTo = all(greaterThanEqual(l.zw, vec2(0.0))) && all(lessThan(l.zw, vec2(1.0)));
    if (inFrom || inTo) {
      // back to the frame's coordinates
      vec2 q = (vec2(i, r) + (inTo ? l.zw : l.xy)) / vec2(n, strips);
      if (backward) q.x = 1.0 - q.x;
      q = vertical ? q.yx : q;
      return inTo ? getToColor(q) : getFromColor(q);
    }
  }
  return background;
}
