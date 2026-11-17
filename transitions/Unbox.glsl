// Author: gre
// License: MIT
// Description: The incoming image is tossed in folded up as an open card box, its middle the floor and its borders the walls, lands with a small bounce after its shadow, then its walls fall open flat one pair after the other, each with a bounce, until the unfolded sheet covers the frame
// Tags: 3d, box, unfold, paper, shadow

// @range(0.1, 0.35) Height of the walls, as a part of the frame's shorter side: the borders of the incoming image that fold up
uniform float depth; // = 0.22
// @range(0, 1) Strength of the perspective
uniform float perspective; // = 0.6
// @range(0, 1) How much the faces darken away from the light, and the shadows they cast
uniform float shading; // = 0.6
// @color Color of the back of the card
uniform vec4 paper; // = vec4(0.93, 0.91, 0.86, 1.0)

const float PI = 3.141592653589793;
const float EDGE = 0.0016;
const float YAW0 = 0.45;
const vec3 LIGHT = vec3(-0.35045, 0.45058, 0.82107);

float wallAngle(float u) {
  float k = u / 0.72;
  return u < 0.72 ? 0.5 * PI * (1.0 - k * k) : 0.12 * sin(PI * (u - 0.72) / 0.28);
}

// sides of quad i: bottom and top walls (1, 2), left and right walls (3, 4), corner tabs (5 to 8)
vec2 sideSign(int i) {
  if (i == 0) return vec2(-1.0);
  if (i == 1) return vec2(0.0, -1.0);
  if (i == 2) return vec2(0.0, 1.0);
  if (i == 3) return vec2(-1.0, 0.0);
  if (i == 4) return vec2(1.0, 0.0);
  return vec2(i == 5 || i == 7 ? -1.0 : 1.0, i < 7 ? -1.0 : 1.0);
}

// hinge corner of quad i on the flat sheet, and the image direction of its two edges (u, v)
vec2 quadOrigin(int i, float W, float c) {
  vec2 sg = sideSign(i);
  return vec2(sg.x > 0.0 ? W - c : c, sg.y > 0.0 ? 1.0 - c : c);
}

vec4 quadAxes(int i) {
  vec2 sg = sideSign(i);
  if (i == 0 || i == 1 || i == 2) return vec4(1.0, 0.0, 0.0, i == 0 ? 1.0 : sg.y);
  if (i == 3 || i == 4) return vec4(0.0, 1.0, sg.x, 0.0);
  return vec4(sg.x, 0.0, 0.0, sg.y);
}

vec2 quadSize(int i, float W, float c) {
  if (i == 0) return vec2(W - 2.0 * c, 1.0 - 2.0 * c);
  if (i == 1 || i == 2) return vec2(W - 2.0 * c, c);
  if (i == 3 || i == 4) return vec2(1.0 - 2.0 * c, c);
  return vec2(c);
}

// edges that are free cuts (s = 0, s = len.x, t = 0, t = len.y), the others are hinges or folds
vec4 quadCut(int i) {
  if (i == 0) return vec4(0.0);
  if (i == 1 || i == 2) return vec4(0.0, 0.0, 0.0, 1.0);
  if (i == 3 || i == 4) return vec4(1.0, 1.0, 0.0, 1.0);
  return vec4(0.0, 1.0, 1.0, 1.0);
}

// edge directions U, V of quad i in box space (columns 0, 1), and its origin (column 2);
// wt holds cos and sin of the bottom/top and side wall angles, tt those of the tabs
mat3 quadFrame(int i, float W, float c, vec4 wt, vec2 tt) {
  vec2 sg = sideSign(i);
  vec3 O = vec3(quadOrigin(i, W, c), 0.0);
  vec3 U = vec3(1.0, 0.0, 0.0), V = vec3(0.0, 1.0, 0.0);
  if (i == 1 || i == 2) {
    V = vec3(0.0, sg.y * wt.x, wt.y);
  } else if (i == 3 || i == 4) {
    U = vec3(0.0, 1.0, 0.0);
    V = vec3(sg.x * wt.z, 0.0, wt.w);
  } else if (i >= 5) {
    // the tabs hang on the bottom and top walls and fold against the outside of the side walls
    V = vec3(0.0, sg.y * wt.x, wt.y);
    U = vec3(sg.x * tt.x, 0.0, 0.0) + tt.y * vec3(0.0, -sg.y * wt.y, wt.x);
  }
  return mat3(U, V, O);
}

vec3 rotate(vec3 v, vec2 rot) {
  return vec3(v.x * rot.x - v.y * rot.y, v.x * rot.y + v.y * rot.x, v.z);
}

// color of quad i at the hit (s, t, coverage, ray dot normal)
vec4 shadeFace(int i, vec4 hit, float W, float c, vec4 wt, vec2 tt, vec2 rot, float amount) {
  if (i < 0) return vec4(0.0);
  mat3 F = quadFrame(i, W, c, wt, tt);
  vec4 ax = quadAxes(i);
  vec2 len = quadSize(i, W, c);
  vec2 st = hit.xy;
  bool front = hit.w * (ax.x * ax.w - ax.y * ax.z) < 0.0;
  vec3 n = rotate(cross(F[0], F[1]), rot) * (front ? 1.0 : -1.0) * (ax.x * ax.w - ax.y * ax.z);
  vec4 col = getToColor(clamp((quadOrigin(i, W, c) + st.x * ax.xy + st.y * ax.zw) / vec2(W, 1.0), 0.0, 1.0));
  float lit = min((0.45 + 0.55 * max(dot(n, LIGHT), 0.0)) / (0.45 + 0.55 * LIGHT.z), 1.0);
  float up = i == 0 ? 0.0 : clamp(F[1].z, 0.0, 1.0);
  if (front) {
    // the image side of a raised wall faces into the box: darker toward the crease with the floor
    lit *= 1.0 - up * (0.35 + 0.4 * (1.0 - st.y / len.y));
    if (i == 0) {
      vec4 ao = exp(-vec4(st.x, len.x - st.x, st.y, len.y - st.y) / (0.25 * c)) * wt.wwyy;
      lit *= 1.0 - 0.45 * max(max(ao.x, ao.y), max(ao.z, ao.w));
    }
    col.rgb = mix(col.rgb, paper.rgb * 0.8, 0.25 * up);
  } else {
    col = vec4(paper.rgb, paper.a * col.a);
  }
  // a lit band along the free top edge of a raised wall reads as the card's thickness
  float rim = up * quadCut(i).w * (1.0 - smoothstep(0.006, 0.014, len.y - st.y));
  col.rgb = mix(col.rgb * mix(1.0, lit, shading * amount), paper.rgb * 1.05, rim * amount);
  return col;
}

vec4 transition(vec2 uv) {
  float W = ratio;
  float c = clamp(depth, 0.1, 0.35) * min(W, 1.0);
  float D = 1.0 / (0.25 + 0.75 * clamp(perspective, 0.0, 1.0));
  float f = clamp(progress / 0.36, 0.0, 1.0);
  float fe = 1.0 - (1.0 - f) * (1.0 - f);
  float h = 0.22 * (1.0 - f * f) + 0.03 * sin(PI * clamp((progress - 0.36) / 0.09, 0.0, 1.0));
  // starts just clear of the frame with its initial yaw, whatever the ratio
  float y0 = 0.52 + 0.5 * W * sin(YAW0) + 0.5 * cos(YAW0);
  vec3 off = vec3(0.0, y0 * (1.0 - fe), h);
  float yaw = YAW0 * (1.0 - fe) * (1.0 - fe);
  vec2 rot = vec2(cos(yaw), sin(yaw));
  float tb = wallAngle(clamp((progress - 0.42) / 0.34, 0.0, 1.0));
  float ts = wallAngle(clamp((progress - 0.6) / 0.4, 0.0, 1.0));
  vec4 wt = vec4(cos(tb), sin(tb), cos(ts), sin(ts));
  vec2 tt = vec2(cos(0.97 * tb), sin(0.97 * tb));
  float amount = clamp(10.0 * (tb + ts + h), 0.0, 1.0);
  float aa = EDGE * amount + 1e-4;
  vec3 C = vec3(0.5 * W, 0.5, 0.0);
  vec3 E = vec3(0.5 * W, 0.5, D);
  vec3 dir = vec3(uv.x * W, uv.y, 0.0) - E;

  // the two nearest faces along the ray, the front one is composited over the back one
  float t1 = 1e4, t2 = 1e4;
  vec4 h1 = vec4(0.0), h2 = vec4(0.0);
  int i1 = -1, i2 = -1;
  for (int i = 0; i < 9; i++) {
    mat3 F = quadFrame(i, W, c, wt, tt);
    vec3 U = rotate(F[0], rot), V = rotate(F[1], rot);
    vec3 n = cross(U, V);
    float den = dot(dir, n);
    if (abs(den) < 1e-6) continue;
    vec3 O = C + rotate(F[2] - C, rot) + off;
    float t = dot(O - E, n) / den;
    if (t <= 0.0 || t >= t2) continue;
    vec3 q = E + t * dir - O;
    vec2 st = vec2(dot(q, U), dot(q, V));
    vec2 len = quadSize(i, W, c);
    vec4 d = vec4(st.x, len.x - st.x, st.y, len.y - st.y);
    vec4 fr = quadCut(i);
    // hinges overlap slightly and cut edges antialias outward, so flat seams never crack
    d = mix(d + 1e-4, d, fr);
    if (min(min(d.x, d.y), min(d.z, d.w)) <= -aa) continue;
    vec4 e = mix(vec4(1.0), clamp(d / aa + 1.0, 0.0, 1.0), fr);
    vec4 hit = vec4(st, e.x * e.y * e.z * e.w, den);
    if (t < t1) { t2 = t1; h2 = h1; i2 = i1; t1 = t; h1 = hit; i1 = i; }
    else { t2 = t; h2 = hit; i2 = i; }
  }

  vec4 c1 = shadeFace(i1, h1, W, c, wt, tt, rot, amount);
  vec4 c2 = shadeFace(i2, h2, W, c, wt, tt, rot, amount);
  vec3 P1 = E + t1 * dir, P2 = E + t2 * dir;

  vec4 ground = getFromColor(uv);
  vec3 G = E + dir;
  float shG = 0.0, sh1 = 0.0, sh2 = 0.0;
  for (int i = 0; i < 9; i++) {
    mat3 F = quadFrame(i, W, c, wt, tt);
    vec3 U = rotate(F[0], rot), V = rotate(F[1], rot);
    vec3 O = C + rotate(F[2] - C, rot) + off;
    vec2 len = quadSize(i, W, c);
    vec3 n = cross(U, V);
    float den = dot(LIGHT, n);
    if (abs(den) < 1e-6) continue;
    for (int k = 0; k < 3; k++) {
      if ((k == 1 && i1 < 0) || (k == 2 && i2 < 0)) continue;
      vec3 P = k == 0 ? G : (k == 1 ? P1 : P2);
      float s = dot(O - P, n) / den;
      if (s < 2e-3) continue;
      vec3 q = P + s * LIGHT - O;
      vec2 st = vec2(dot(q, U), dot(q, V));
      float soft = 0.004 + 0.12 * s;
      float inside = min(min(st.x, len.x - st.x), min(st.y, len.y - st.y));
      float a = smoothstep(-soft, soft, inside) / (1.0 + 1.5 * s);
      if (k == 0) shG = max(shG, a); else if (k == 1) sh1 = max(sh1, a); else sh2 = max(sh2, a);
    }
  }
  float sk = 0.9 * shading * amount * min(8.0 * progress, 1.0);
  ground.rgb *= 1.0 - sk * shG;
  c1.rgb *= 1.0 - sk * sh1;
  c2.rgb *= 1.0 - sk * sh2;
  return mix(mix(ground, c2, h2.z), c1, h1.z);
}
