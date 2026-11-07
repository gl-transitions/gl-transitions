// Author: gre
// License: MIT
// Description: The frame becomes the face of a twisty cube puzzle: dark gaps open between its cubies, then whole columns and rows of cubies turn a quarter turn around the cube one after another in 3D, each bringing the incoming image from the cube's side to the front, until the gaps close on the incoming image
// Tags: 3d, rotate, grid

// @range(2, 8, 1) Number of cubies along each side of the face
uniform int size; // = 3
// @range(0, 0.05) Width of the gaps between the cubies, as a part of the frame's height
uniform float gap; // = 0.012
// @range(0, 1) How much the turning sides darken away from the light, and the shadows inside the cube
uniform float shading; // = 0.6
// @color Color of the cubies' body, seen in the gaps, on their inner sides and around the cube
uniform vec4 background; // = vec4(0.04, 0.04, 0.05, 1.0)

const float PI = 3.141592653589793;
// delay between the turns of a group, as a part of a turn
const float STAGGER = 0.45;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0012;

float gridSize() {
  return float(size < 2 ? 2 : (size > 8 ? 8 : size));
}

// the turns run in 3 groups, one after the other: the even columns, the even rows (counted from the top),
// then the odd columns; the turns of a group overlap
float groupLength(float m) {
  return m > 0.0 ? 1.0 + (m - 1.0) * STAGGER : 0.0;
}

// the time in turn units, and the length of the groups of even and odd slices
vec3 timeline(float n) {
  float lenEven = groupLength(floor((n + 1.0) * 0.5));
  float lenOdd = groupLength(floor(n * 0.5));
  float u = clamp((progress - 0.05) / 0.85, 0.0, 1.0) * (2.0 * lenEven + lenOdd);
  return vec3(u, lenEven, lenOdd);
}

// the turn of a column (isCol) or of a row, 0 at rest to 1 turned
float turnTime(vec3 tl, bool isCol, float idx, float n) {
  // rows are counted from the top
  float k = isCol ? idx : n - 1.0 - idx;
  bool odd = mod(k, 2.0) > 0.5;
  // the odd rows never turn: the columns already brought the incoming image there
  if (odd && !isCol) return 0.0;
  float start = (odd ? 2.0 * tl.y : (isCol ? 0.0 : tl.y)) + floor(k * 0.5) * STAGGER;
  return clamp(tl.x - start, 0.0, 1.0);
}

// the turn's direction: +1 brings the side of the cube at higher coordinates to the front
float turnDir(bool isCol, float idx) {
  return mod(idx + (isCol ? 0.0 : 1.0), 2.0) < 0.5 ? 1.0 : -1.0;
}

// eased angle, landing with a little speed left like a click
float turnAngle(float t) {
  return 0.5 * PI * mix(t, t * t * (3.0 - 2.0 * t), 0.8);
}

// 1 on the cubies' faces, 0 in the gaps, at the point fp of the face (frame heights)
float faceMask(vec2 fp, float n, float g) {
  if (g <= 0.0) return 1.0;
  vec2 cell = vec2(ratio, 1.0) / n;
  vec2 c = fp / cell;
  vec2 r = floor(c + 0.5);
  // distance to the nearest cubie edge inside the face (the face's own border has no gap)
  vec2 d = abs(c - r) * cell;
  d.x = (r.x < 0.5 || r.x > n - 0.5) ? 1.0 : d.x;
  d.y = (r.y < 0.5 || r.y > n - 0.5) ? 1.0 : d.y;
  float e = min(EDGE, 0.5 * g);
  return smoothstep(0.5 * g - e, 0.5 * g + e, min(d.x, d.y));
}

// does the cubie of the face at fp show the incoming image, from the turns done so far
bool isDone(vec3 tl, vec2 fp, float n) {
  vec2 cell = clamp(floor(fp / (vec2(ratio, 1.0) / n)), 0.0, n - 1.0);
  return turnTime(tl, true, cell.x, n) >= 1.0 || turnTime(tl, false, cell.y, n) >= 1.0;
}

vec4 sticker(vec2 fp, bool incoming, float light, float n, float g) {
  vec2 uv = clamp(fp / vec2(ratio, 1.0), 0.0, 1.0);
  vec4 img = incoming ? getToColor(uv) : getFromColor(uv);
  vec4 body = vec4(background.rgb * light, background.a);
  return mix(body, vec4(img.rgb * light, img.a), faceMask(fp, n, g));
}

// brightness of a face of normal nrm (across the slices, along the turn, depth) in the turn's space, 1 facing the viewer
float lighting(vec3 nrm, bool isCol) {
  vec3 l = normalize(vec3(-0.35, 0.55, 1.0));
  if (isCol) l = l.yxz;
  return 1.0 - shading * (1.0 - clamp(dot(nrm, l) / l.z, 0.0, 1.0));
}

vec2 rot(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// casts the ray (o, d), in the turn's space (across the slices, along the turn, depth), onto the slice
// [a0, a0 + w] turned by the angle a around the middle of the cube (a square section of side S):
// returns the ray's parameter at the hit (or -1), the face hit (0 front, 1 back, 2 and 3 the sides
// at higher and lower coordinates along the turn at rest, 4 the slice's ends), and the point hit
// (across the slices, and across the face, -1 to 1)
vec4 sliceHit(vec3 o, vec3 d, float a0, float w, float S, float a) {
  vec2 lo = rot(o.yz - vec2(0.5 * S, -0.5 * S), -a);
  vec2 ld = rot(d.yz, -a);
  ld = vec2(abs(ld.x) < 1e-6 ? 1e-6 : ld.x, abs(ld.y) < 1e-6 ? 1e-6 : ld.y);
  float dx = abs(d.x) < 1e-6 ? 1e-6 : d.x;
  vec3 t1 = vec3((a0 - o.x) / dx, (-0.5 * S - lo) / ld);
  vec3 t2 = vec3((a0 + w - o.x) / dx, (0.5 * S - lo) / ld);
  vec3 tn = min(t1, t2);
  vec3 tf = max(t1, t2);
  float tNear = max(tn.x, max(tn.y, tn.z));
  float tFar = min(tf.x, min(tf.y, tf.z));
  if (tNear > tFar || tNear <= 0.0) return vec4(-1.0);
  vec2 q = (lo + tNear * ld) / (0.5 * S);
  float across = o.x + tNear * d.x;
  if (tn.x >= tn.y && tn.x >= tn.z) return vec4(tNear, 4.0, across, sign(-dx));
  if (tn.y > tn.z) return vec4(tNear, ld.x < 0.0 ? 2.0 : 3.0, across, q.y);
  return vec4(tNear, ld.y < 0.0 ? 0.0 : 1.0, across, q.x);
}

// the color of a turning slice at its hit
vec4 sliceColor(vec4 hit, vec3 tl, bool isCol, float a, float dir, float S, float n, float g) {
  float f = hit.y;
  if (f > 3.5) return vec4(background.rgb * lighting(vec3(hit.w, 0.0, 0.0), isCol), background.a);
  vec2 nl = f < 0.5 ? vec2(0.0, 1.0) : f < 1.5 ? vec2(0.0, -1.0) : f < 2.5 ? vec2(1.0, 0.0) : vec2(-1.0, 0.0);
  float light = lighting(vec3(0.0, rot(nl, a)), isCol);
  // the front shows what the cubies showed before this turn, the side that comes to the front
  // shows the incoming image where it lands
  bool front = f < 0.5;
  bool coming = nl.x * dir > 0.5;
  if (!front && !coming) return vec4(background.rgb * light, background.a);
  // on the side coming to the front, the point across lands at -dir times its depth
  float r = 0.5 * S * (1.0 + (front ? hit.w : -dir * hit.w));
  vec2 fp = isCol ? vec2(hit.z, r) : vec2(r, hit.z);
  return sticker(fp, coming || isDone(tl, fp, n), light, n, g);
}

vec4 transition(vec2 uv) {
  float n = gridSize();
  vec3 tl = timeline(n);
  // the gaps open at the start and close at the end, after the last turn
  float g = gap * smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
  vec2 P = vec2(uv.x * ratio, uv.y);

  // the turns going on are of columns or of rows, never both
  bool isCol = tl.x < tl.y || tl.x >= 2.0 * tl.y;
  // the turn's space: (across the slices, along the turn, depth toward the viewer);
  // a column turns around the horizontal axis through the middle of the cube, a row around the vertical one
  float w = (isCol ? ratio : 1.0) / n;
  float S = isCol ? 1.0 : ratio;
  vec2 pp = isCol ? P : P.yx;
  vec3 o = vec3(isCol ? vec2(0.5 * ratio, 0.5) : vec2(0.5, 0.5 * ratio), 1.2 + 0.6 * max(ratio, 1.0));
  // the ray reaches the face (z = 0) at t = 1
  vec3 d = vec3(pp, 0.0) - o;

  float k0 = clamp(floor(pp.x / w), 0.0, n - 1.0);
  float t0 = turnTime(tl, isCol, k0, n);

  float nearest = 1.0;
  vec4 color;
  if (t0 <= 0.0 || t0 >= 1.0) {
    // the face at rest: the exact image
    color = isDone(tl, P, n) ? getToColor(uv) : getFromColor(uv);
    color = mix(background, color, faceMask(P, n, g));
    // the shade of the turning slices next to this one, deepest mid-turn
    for (int j = -1; j <= 1; j += 2) {
      float k = k0 + float(j);
      if (k < 0.0 || k > n - 1.0) continue;
      float tk = turnTime(tl, isCol, k, n);
      if (tk <= 0.0 || tk >= 1.0) continue;
      float dist = abs(pp.x - (k + 0.5) * w) - 0.5 * w;
      color.rgb *= 1.0 - 0.5 * shading * sin(2.0 * turnAngle(tk)) * exp(-dist / (0.2 * w));
    }
  } else {
    // inside the hollow left by the turning slice: the sides of the slices next to it and the cube's inside, in the dark
    float tw = abs(d.x) < 1e-6 ? 1e6 : (d.x < 0.0 ? k0 * w - o.x : (k0 + 1.0) * w - o.x) / d.x;
    float tb = (o.z + S) / -d.z;
    nearest = min(tw, tb);
    float along = o.y + nearest * d.y;
    float depth = (o.z + nearest * d.z) / -S;
    float light = tw < tb ? lighting(vec3(-sign(d.x), 0.0, 0.0), isCol) : 1.0;
    light *= 1.0 - shading * (0.5 + 0.4 * clamp(depth, 0.0, 1.0));
    // beyond the cube's edges: the background
    color = along < 0.0 || along > S ? background : vec4(background.rgb * light, background.a);
  }

  // the turning slices, which come out in front of the face as they turn
  for (int j = -1; j <= 1; j++) {
    float k = k0 + float(j);
    if (k < 0.0 || k > n - 1.0) continue;
    float tk = turnTime(tl, isCol, k, n);
    if (tk <= 0.0 || tk >= 1.0) continue;
    float dir = turnDir(isCol, k);
    float a = dir * turnAngle(tk);
    vec4 hit = sliceHit(o, d, k * w, w, S, a);
    if (hit.x > 0.0 && hit.x < nearest) {
      nearest = hit.x;
      color = sliceColor(hit, tl, isCol, a, dir, S, n, g);
    }
  }
  return color;
}
