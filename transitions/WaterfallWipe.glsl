// Author: gre
// License: MIT
// Description: Blocks of the incoming image pour down from above the frame column after column, like a waterfall: in each column they fall one behind the other, land with a small bounce and stack up from the bottom, casting soft shadows on the outgoing image until the stack fills the frame
// Tags: blocks, grid, fall, cascade, stack, gravity, shadow

// @range(2, 40, 1) Number of columns (the blocks stay about square, with at most 48 rows)
uniform int columns; // = 10
// @range(0, 0.8) Share of the transition over which the columns start one after another (0 pours them all together)
uniform float stagger; // = 0.45
// @range(0, 1) How high the blocks bounce as they land
uniform float bounce; // = 0.5
// @range(0, 1) Darkness of the shadows and of the edges of the falling blocks
uniform float shadow; // = 0.5
// @param The columns pour from right to left instead of left to right
uniform bool reverse; // = false

// blocks per column, at most
const int MAX_ROWS = 48;
// time between two blocks of a column, as a part of the time it takes a block to fall its own height
const float SPACING = 1.15;
// time the edges and shadow of a block take to fade after its bounce, as a part of the frame's fall
const float SETTLE = 0.15;
// speed the blocks are thrown in with, as a part of the speed they reach after a fall of the frame's height
const float THROW = 0.25;
// how much a falling block grows, as it is seen closer to the camera
const float GROW = 0.06;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0015;

// signed distance to a box of half size b, negative inside
float boxDist(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - abs(v));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  float nc = clamp(float(columns), 1.0, 40.0);
  float nr = clamp(floor(nc / ratio + 0.5), 1.0, float(MAX_ROWS));
  // a cell, and this point, in frame heights
  vec2 cell = vec2(ratio / nc, 1.0 / nr);
  vec2 x = uv * vec2(ratio, 1.0);
  float here = clamp(floor(uv.x * nc), 0.0, nc - 1.0);

  // the blocks start just above the frame, their grown size and anti-aliased edge included
  float top = 1.0 + 0.5 * GROW * cell.y + 2.0 * EDGE;
  // timing: g = 2 / u^2 is the gravity and 2 w / u the speed the blocks are thrown down with, so that a fall
  // of height h takes u (sqrt(w^2 + h) - w); d is the time between two blocks of a column, e the speed a block
  // bounces back with, as a part of its landing speed. The top block of the last column settles last, right
  // at the end
  float st = nc > 1.0 ? clamp(stagger, 0.0, 0.8) : 0.0;
  float w = THROW;
  float e = 0.2 * clamp(bounce, 0.0, 1.0);
  float hTop = sqrt(w * w + top - (nr - 1.0) * cell.y);
  float dn = SPACING * (sqrt(w * w + cell.y) - w);
  float u = (1.0 - st) / (dn * (nr - 1.0) + hTop - w + 2.0 * e * hTop + SETTLE);
  float d = dn * u;
  float k = clamp(shadow, 0.0, 1.0);

  // the two highest blocks seen here (height, coverage, image point) and the shadow cast here
  float z1 = -1.0, z2 = -1.0, m1 = 0.0, m2 = 0.0, a1 = 0.0, a2 = 0.0, shade = 0.0;
  vec2 s1 = vec2(0.0), s2 = vec2(0.0);
  vec2 light = vec2(0.35, -0.5) * min(cell.x, cell.y);
  for (int i = 0; i < 3; i++) {
    float c = here + float(i) - 1.0;
    if (c < 0.0 || c >= nc) continue;
    float order = reverse ? nc - 1.0 - c : c;
    float t0 = nc > 1.0 ? st * order / (nc - 1.0) : 0.0;
    // the top of the block below, which the next block cannot go through
    float floorY = 0.0;
    for (int j = 0; j < MAX_ROWS; j++) {
      float r = float(j);
      if (r >= nr) break;
      float slot = r * cell.y;
      // it falls freely to its slot and bounces back up a little
      float s = progress - t0 - r * d;
      // this block and the ones above it have not set off yet: they are all still above the frame
      if (s <= 0.0) break;
      float rh = sqrt(w * w + top - slot);
      float land = u * (rh - w);
      float y = top;
      float air = 1.0;
      if (s > land) {
        // it bounces back up with e times its landing speed, 2 rh / u
        float b = s - land;
        y = slot + max(0.0, b * (2.0 * e * rh - b / u) / u);
        air = 1.0 - smoothstep(0.0, (2.0 * e * rh + SETTLE) * u, b);
      } else {
        y = top - s * (2.0 * w + s / u) / u;
      }
      y = max(y, floorY);
      floorY = y + cell.y;
      float z, cov, a;
      vec2 src;
      if (air <= 0.0 && y - slot < 0.02 * cell.y) {
        // at rest in its slot: it fills its cell exactly
        if (c != here || x.y < slot || x.y >= slot + cell.y || z2 >= 0.0) continue;
        z = 0.0; cov = 1.0; a = 0.0; src = uv;
      } else {
        // how much of it has come into the frame
        float inFrame = clamp((1.0 - y) / cell.y, 0.0, 1.0);
        vec2 center = vec2((c + 0.5) * cell.x, y + 0.5 * cell.y);
        float sc = 1.0 + GROW * air;
        vec2 q = (x - center) / sc;
        // its shadow on what lies below it, further away and softer the higher it is
        float blur = 0.002 + 0.3 * air * cell.y;
        float sd = boxDist(x - center - light * air, 0.5 * cell * sc);
        shade = max(shade, (1.0 - smoothstep(-blur, blur, sd)) * air * inFrame);
        float dist = boxDist(q, 0.5 * cell) * sc;
        // anti-aliased while it falls; it sharpens as it settles, to tile with the blocks around it
        float aa = EDGE * min(8.0 * air, 1.0);
        cov = aa > 0.0 ? clamp(0.5 - dist / aa, 0.0, 1.0) : step(dist, 0.0);
        z = air + 0.001 * r;
        if (cov <= 0.0 || z <= z2) continue;
        src = (vec2(c, r) * cell + q + 0.5 * cell) / vec2(ratio, 1.0);
        // its bevel: lit along its top and left edges, darker along its bottom and right ones
        vec2 lq = q / (0.5 * cell);
        float bev = 1.0 - smoothstep(0.0, 0.12, -dist / min(cell.x, cell.y));
        a = air * bev * 0.5 * (lq.y - lq.x);
      }
      if (z > z1) {
        z2 = z1; m2 = m1; a2 = a1; s2 = s1;
        z1 = z; m1 = cov; a1 = a; s1 = src;
      } else {
        z2 = z; m2 = cov; a2 = a; s2 = src;
      }
    }
  }

  // the shadows fall on the outgoing image and on the blocks at rest, not on the moving ones
  vec4 col = getFromColor(uv);
  col.rgb *= 1.0 - 0.6 * k * shade;
  if (m2 > 0.0 && m1 < 1.0) {
    vec4 b = getToColor(mirror(s2));
    b.rgb = clamp(b.rgb * (1.0 + 0.6 * k * a2) * (1.0 - 0.6 * k * shade * step(z2, 0.0)), 0.0, 1.0);
    col = mix(col, b, m2);
  }
  if (m1 > 0.0) {
    vec4 b = getToColor(mirror(s1));
    b.rgb = clamp(b.rgb * (1.0 + 0.6 * k * a1) * (1.0 - 0.6 * k * shade * step(z1, 0.0)), 0.0, 1.0);
    col = mix(col, b, m1);
  }
  return col;
}
