// Author: gre
// License: MIT
// Description: Thin cracks run through the outgoing image along its own outlines, then the pieces they cut sag loose and fall away one after another from the top, tumbling and shrinking into the incoming image beneath
// Tags: crumble, pieces, cracks, falling

// @range(2, 10) Pieces across the height of the frame
uniform float cells; // = 4.0
// @range(0, 12) How closely the cracks follow the outlines of the picture
uniform float follow; // = 4.0

vec2 hash22(vec2 p) {
  vec3 p3 = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}
vec2 toUV(vec2 q) { return vec2(q.x / ratio, q.y) / cells; }
vec2 seedOf(vec2 c) { return c + 0.5 + 0.6 * (hash22(c) - 0.5); }
// blurred color of the outgoing picture around q, r cells wide, so grain and texture do not fray the cracks
vec3 soft(vec2 q, float r) {
  vec2 u = clamp(toUV(q), 0.0, 1.0), ex = vec2(r / (cells * ratio), 0.0), ey = vec2(0.0, r / cells);
  return (getFromColor(u + ex).rgb + getFromColor(u - ex).rgb + getFromColor(u + ey).rgb + getFromColor(u - ey).rgb) * 0.25;
}
// the piece that owns q: a Voronoi cell whose distance grows with color difference,
// so cracks snap to the outlines of the picture. z = distance to the crack, in cells
vec3 owner(vec2 q) {
  // the pixel's color is blurred, each seed's is a single tap (the penalty is capped, so an odd one costs little)
  vec3 col = soft(q, 0.25);
  vec2 base = floor(q), best = base, s1 = q, s2 = q;
  float d1 = 1e9, d2 = 1e9;
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 c = base + vec2(float(i), float(j));
    vec2 s = seedOf(c), dq = q - s;
    vec3 dc = col - getFromColor(clamp(toUV(s), 0.0, 1.0)).rgb;
    float d = dot(dq, dq) + follow * min(dot(dc, dc), 0.04);
    if (d < d1) { d2 = d1; s2 = s1; d1 = d; s1 = s; best = c; } else if (d < d2) { d2 = d; s2 = s; }
  }
  return vec3(best, (d2 - d1) / (2.0 * length(s2 - s1) + 1e-3));
}
// whether the piece of cell c can own q at all: owner() only looks at the 3x3 cells around q,
// and the color penalty is at most follow * 0.04, so a seed much farther than the nearest one cannot win
// (a cheap test, without texture taps, before the full owner())
bool mayOwn(vec2 q, vec2 c) {
  vec2 base = floor(q);
  if (abs(c.x - base.x) > 1.0 || abs(c.y - base.y) > 1.0) return false;
  float dmin = 1e9;
  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
    vec2 dq = q - seedOf(base + vec2(float(i), float(j)));
    dmin = min(dmin, dot(dq, dq));
  }
  vec2 dc = q - seedOf(c);
  return dot(dc, dc) <= dmin + follow * 0.04;
}
// fall time of the piece of cell c, whose seed is s: top pieces go first, with some disorder
float localTime(vec2 c, vec2 s) {
  float y = clamp(s.y / cells, 0.0, 1.0);
  float d = 0.75 * (1.0 - y) + 0.25 * hash22(c + 7.0).x;
  return (progress - 0.2 - 0.46 * d) / 0.32;
}
mat2 rot(float a) { return mat2(cos(a), -sin(a), sin(a), cos(a)); }

vec4 transition(vec2 uv) {
  vec2 P = vec2(uv.x * ratio, uv.y) * cells;
  vec3 own = owner(P);
  float px = cells / 200.0; // crack width scales with the frame height
  // first the cracks run down the picture
  float crack = smoothstep(0.0, 0.1, progress - 0.1 * (1.0 - uv.y));
  float core = 1.0 - smoothstep(0.6 * px, 1.6 * px, own.z);
  float rim = (1.0 - smoothstep(1.6 * px, 3.2 * px, own.z)) - core;
  vec4 from = getFromColor(uv);
  vec4 col = vec4(from.rgb * (1.0 - 0.85 * core * crack) * (1.0 + 0.2 * rim * crack), from.a);
  if (localTime(own.xy, seedOf(own.xy)) > 0.0) {
    // the hole left behind: the incoming picture, shaded until most pieces are gone
    vec4 to = getToColor(uv);
    col = vec4(to.rgb * (1.0 - 0.5 * (1.0 - smoothstep(0.45, 1.0, progress))), to.a);
  }
  // falling pieces; the most recently released one is on top
  float top = 2.0;
  for (int j = -1; j <= 3; j++) for (int i = -1; i <= 1; i++) {
    vec2 c = floor(P) + vec2(float(i), float(j));
    vec2 s = seedOf(c);
    float t = localTime(c, s);
    if (t <= 0.0 || t >= 1.0 || t >= top) continue;
    // it sags out of its socket, then drops, tumbles and shrinks away
    float loose = smoothstep(0.0, 0.18, t);
    float f = max(t - 0.15, 0.0) / 0.85;
    float g = f * f;
    float spin = hash22(c + 3.0).x - 0.5;
    float a = spin * (0.12 * loose + 1.6 * g);
    float scale = 1.0 - 0.6 * g;
    vec2 d = rot(a) * (P - s - vec2(0.0, -0.06 * loose - 1.7 * g)) / scale;
    vec2 q = s + d;
    vec2 qu = toUV(q);
    if (qu.x < 0.0 || qu.x > 1.0 || qu.y < 0.0 || qu.y > 1.0 || !mayOwn(q, c)) continue;
    vec3 o = owner(q);
    if (any(notEqual(o.xy, c))) continue;
    // beveled edge, lit from above; darker as it falls away
    float bev = 1.0 - smoothstep(0.0, 0.1, o.z);
    vec2 n = rot(-a) * normalize(q - s + 1e-4);
    vec4 fc = getFromColor(qu);
    vec3 pc = fc.rgb * (1.0 + bev * 0.35 * n.y) * (1.0 - 0.5 * g);
    float edge = smoothstep(0.0, 1.5 * px / scale, o.z);
    col = mix(col, vec4(pc, fc.a), (1.0 - smoothstep(0.8, 1.0, t)) * edge);
    // only a piece that really covers the pixel hides the older ones behind it, not its antialiased rim
    if (edge > 0.5) top = t;
  }
  return col;
}
