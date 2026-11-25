// Author: gre
// License: MIT
// Description: Quilt blocks are pieced over the outgoing image out of strips in the incoming image's colors, wound round each block's heart: every strip is laid face down along its seam and flips open, then a second round of strips flips open on top with the incoming image printed on them
// Tags: quilt, strips, fold, pattern, geometric, colorful
// Preview: 0.5

// @range(1, 6, 1) Number of quilt blocks along the shorter side of the frame
uniform float rows; // = 2.0
// @range(0, 1) How spread out in time the blocks start
uniform float spread; // = 0.5
// @range(0, 1) Strength of the seams and of the shadows under the strips
uniform float relief; // = 0.6

const float RINGS = 4.0;
// strips it takes one strip to flip open, so a few move at once
const float D = 3.0;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float turnOf(float t, float idx) {
  t = clamp(t, 0.0, 1.0);
  t *= 1.4 - 0.4 * t;
  return clamp(((4.0 * RINGS + D) * t - idx) / D, 0.0, 1.0);
}

vec2 quarter(vec2 v, float n) {
  return n < 0.5 ? v : n < 1.5 ? vec2(-v.y, v.x) : n < 2.5 ? -v : vec2(v.y, -v.x);
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

float acrossOf(float ring, float side, vec2 q) {
  return ring < 0.5 ? 2.0 * max(abs(q.x), abs(q.y)) : quarter(q, side).y - ring + 0.5;
}

// x: rank in which the leaf was sewn on, y: coverage of this pixel, z: shadow it casts here,
// w: how far it reaches from its seam, negative while face down
vec4 leafAt(int i, vec2 q, float now, float aa) {
  float layer = i < 9 ? 0.0 : 1.0;
  int j = i < 9 ? i : i - 9;
  bool heart = j == 8;
  float side = heart ? 0.0 : floor(0.5 * float(j));
  vec2 w = quarter(q, side);
  // for each side, the strip sewn here and the next one folded over it
  float ring = heart ? 0.0 : floor(w.y + 0.5) + mod(float(j), 2.0);
  float across = acrossOf(ring, side, q);
  bool on = heart ? across < 1.0 : ring > 0.5 && ring < RINGS + 0.5 && w.x >= -ring - 0.5 && w.x < ring - 0.5;
  float idx = heart ? 0.0 : (ring - 1.0) * 4.0 + side + 1.0;
  float s = turnOf((now - 0.42 * layer) / (0.56 + 0.02 * layer), idx);
  if (!on || s <= 0.0) return vec4(-1.0, 0.0, 1.0, 0.0);
  // the strip is laid down along its seam, then folded open
  float laid = clamp(s / 0.4, 0.0, 1.0) * (2.0 * ring + aa);
  float along = heart ? 1.0 : 1.0 - smoothstep(laid - aa, laid, w.x + ring + 0.5);
  if (!heart) s = clamp((s - 0.2) / 0.8, 0.0, 1.0);
  s *= s * (3.0 - 2.0 * s);
  float reach = heart ? s : -cos(3.14159265 * s);
  float lift = sin(3.14159265 * s);
  bool same = across * reach >= 0.0;
  float beyond = same ? abs(across) - abs(reach) * (1.0 + aa) : abs(across);
  float m = same ? along * (1.0 - smoothstep(-aa, 0.0, beyond)) : 0.0;
  float sh = 0.45 * relief * lift * along * (1.0 - m) * (1.0 - smoothstep(0.0, 0.1 + 0.4 * lift, beyond));
  return vec4(100.0 * layer + idx, m, 1.0 - sh, reach);
}

vec4 cloth(vec4 at, vec2 q, vec2 cell, vec2 res, float mir, float unit) {
  float layer = at.x < 99.5 ? 0.0 : 1.0;
  float idx = at.x - 100.0 * layer;
  bool heart = idx < 0.5;
  float ring = floor((idx + 3.0) / 4.0);
  float side = heart ? 0.0 : idx - 4.0 * ring + 3.0;
  bool face = at.w > 0.0;
  bool printed = face && layer > 0.5;
  float lift = sqrt(max(1.0 - at.w * at.w, 0.0));
  float back = mod(4.0 - side, 4.0);
  float reach = max(abs(at.w), 0.05);
  vec2 fit = 0.5 * unit / res;
  vec2 mid = (cell + 0.5) / res;
  vec2 flip = vec2(mir, 1.0);
  vec4 c;
  if (printed) {
    vec2 w = heart ? q / reach : quarter(q, side);
    if (!heart) {
      w.y = ring - 0.5 + (w.y - ring + 0.5) / reach;
      w = quarter(w, back);
    }
    c = premultiplied(getToColor(mid + fit * flip * w));
  } else {
    // averaged along the strip, so it does not flicker with the grain of a video
    c = vec4(0.0);
    for (int i = 0; i < 4; i++) {
      float at = (float(i) - 1.5) * 0.4;
      vec2 m = heart ? vec2(at, 0.2 * at) : quarter(vec2(at * ring - 0.5, ring + 0.2 * at), back);
      c += 0.25 * premultiplied(getToColor(mid + fit * flip * m));
    }
    // a block is light on one side of its diagonal and dark on the other
    float tone = heart ? 0.0 : (side < 1.5 ? 0.26 : -0.26) + 0.06 * (mod(ring, 2.0) * 2.0 - 1.0);
    if (!face) tone = mix(tone, 0.25, 0.6);
    c.rgb += tone * (tone > 0.0 ? vec3(c.a) - c.rgb : c.rgb);
  }
  float shade = relief * lift * (face ? -0.3 : 0.12);
  c.rgb += shade * (shade > 0.0 ? vec3(c.a) - c.rgb : c.rgb);
  float x = clamp(abs(acrossOf(ring, side, q)) / reach, 0.0, 1.0);
  float edge = heart ? x : abs(2.0 * x - 1.0);
  edge *= edge;
  c.rgb *= 1.0 - 0.28 * relief * (printed ? lift : 1.0) * edge * edge * edge;
  return c;
}

vec4 transition(vec2 uv) {
  float n = max(floor(rows + 0.5), 1.0);
  vec2 res = max(floor(n * vec2(max(ratio, 1.0), max(1.0 / ratio, 1.0)) + 0.5), 1.0);
  vec2 g = uv * res;
  vec2 cell = floor(g);
  vec2 q = 2.0 * (g - cell) - 1.0;
  float mir = mod(cell.x + cell.y, 2.0) * 2.0 - 1.0;
  q.x *= mir;
  float unit = 1.0 / (RINGS + 0.5);
  // kept off the block's border, which no strip owns
  q = clamp(q, -0.9999, 0.9999) / unit;
  float aa = 0.005 * res.y / unit;
  float delay = 0.35 * spread * hash12(cell + 5.0);
  float now = (progress - delay) / (1.0 - 0.35 * spread);

  vec4 top = vec4(-1.0, 0.0, 1.0, 0.0);
  vec4 under = top;
  for (int i = 0; i < 18; i++) {
    vec4 at = leafAt(i, q, now, aa);
    if (at.y > 0.0 && at.x > top.x) {
      under = top;
      top = at;
    } else if (at.y > 0.0 && at.x > under.x) under = at;
  }
  // a leaf only casts its shadow on those sewn on before it
  vec2 shade = vec2(1.0);
  for (int i = 0; i < 18; i++) {
    vec4 at = leafAt(i, q, now, aa);
    if (at.x > top.x) shade.x *= at.z;
    else if (at.x > under.x && at.x < top.x) shade.y *= at.z;
  }
  vec4 col = premultiplied(getFromColor(uv));
  if (under.x > -0.5) col = cloth(under, q, cell, res, mir, unit);
  col.rgb *= shade.y;
  if (top.x > -0.5) col = mix(col, cloth(top, q, cell, res, mir, unit), top.y);
  col.rgb *= shade.x;
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
