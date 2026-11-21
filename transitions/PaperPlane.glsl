// Author: gre
// License: MIT
// Description: The outgoing image is folded into a paper plane: its two left corners fold back to the middle, it folds in half behind itself, the wings fold out, and the plane banks and glides away into the distance over the incoming image
// Tags: paper, fold, origami, plane, 3d, fly

// @range(0, 1) Darkness of the faces turned away from the light and of the plane's shadow
uniform float shading; // = 0.5
// @color Color of the back of the paper
uniform vec4 paper; // = vec4(0.96, 0.95, 0.91, 1.0)

const float PI = 3.141592653589793;
const float K = 0.1;
// the corner folds run from the nose to this far along the top and bottom edges
const float HINGE = 0.75;
const float CAM = 2.6;
const vec3 LIGHT = vec3(-0.36, 0.48, 0.8);

float W, af, ah, aw, roll, yaw;
bool portrait;
vec2 hu;
vec3 shift;

vec3 rot(vec3 p, vec3 a, vec3 d, float ang) {
  p -= a;
  float c = cos(ang), s = sin(ang);
  return a + p * c + cross(d, p) * s + d * dot(d, p) * (1.0 - c);
}

// sheet point (x in [0, W], y in [-0.5, 0.5], z = 0) to world, for one piece of the plane
vec3 place(vec3 p, bool top, bool flap, bool wing) {
  if (flap) p = rot(p, vec3(0.0), vec3(hu.x, top ? hu.y : -hu.y, 0.0), top ? -af : af);
  if (!top) p = rot(p, vec3(0.0), vec3(1.0, 0.0, 0.0), ah);
  if (wing) p = rot(p, vec3(0.0), normalize(vec3(1.0, K, 0.0)), top ? aw : -aw);
  vec3 pivot = vec3(0.5 * W, 0.1, 0.0);
  p = rot(p, pivot, vec3(1.0, 0.0, 0.0), roll);
  p = rot(p, pivot, vec3(0.0, 0.0, 1.0), yaw);
  return p - vec3(0.5 * W, 0.0, 0.0) + shift;
}

// signed distance inside the piece, in sheet coordinates: (outer edges, creases)
vec2 inside(vec2 s, bool top, bool flap, bool wing) {
  float d = min(min(s.x, W - s.x), min(s.y + 0.5, 0.5 - s.y));
  vec2 m = vec2(s.x, top ? s.y : -s.y);
  float hinge = m.x * hu.y - m.y * hu.x;
  // a flap is seen where it lands, mirrored across its hinge; the part that would cross the
  // middle is dropped once it is hidden behind the sheet
  vec2 f = flap ? 2.0 * dot(m, hu) * hu - m : m;
  float n = inversesqrt(1.0 + K * K);
  float crease = (K * f.x - f.y) * n;
  float c = min(min(m.y, flap ? -hinge : hinge), wing ? -crease : crease);
  if (flap && af > 0.6 * PI) c = min(c, f.y);
  return vec2(d, c);
}

// n faces the camera
vec4 shadeFace(vec2 s, vec3 n, bool front) {
  float lit = clamp(dot(n, LIGHT), 0.0, 1.0);
  vec2 t = vec2(s.x / W, s.y + 0.5);
  vec4 c = front ? getFromColor(portrait ? vec2(t.y, 1.0 - t.x) : t) : paper;
  // flat on the frame (lit == LIGHT.z) the face keeps its exact color
  c.rgb *= lit < LIGHT.z ? 1.0 - shading * (LIGHT.z - lit) / LIGHT.z : 1.0 + 0.3 * shading * (lit - LIGHT.z) / (1.0 - LIGHT.z);
  return c;
}

vec4 transition(vec2 uv) {
  // the nose points along the long side of the frame
  portrait = ratio < 1.0;
  W = portrait ? 1.0 / ratio : ratio;
  vec2 st = portrait ? vec2(1.0 - uv.y, uv.x) : uv;
  hu = normalize(vec2(HINGE * W, 0.5));
  float p = progress;
  float e1 = smoothstep(0.0, 0.24, p);
  float e2 = smoothstep(0.2, 0.42, p);
  float e3 = smoothstep(0.4, 0.62, p);
  float e4 = smoothstep(0.55, 1.0, p);
  af = PI * e1 * 0.999;
  ah = PI * e2 * 0.999;
  // wings stop short of flat so they keep a slight V
  aw = 0.4 * PI * e3;
  roll = -0.9 * e3 + 0.35 * sin(PI * e4);
  yaw = -0.25 * e3 - 0.2 * e4;
  float f = e4 * e4;
  shift = vec3(0.35 * e3 - 3.3 * f, 0.15 * e3 + 2.2 * f, -1.2 * e3 - 5.5 * f);

  vec3 O[8], EX[8], EY[8];
  for (int i = 0; i < 8; i++) {
    bool top = i < 4;
    bool flap = mod(float(i), 4.0) > 1.5;
    bool wing = mod(float(i), 2.0) > 0.5;
    O[i] = place(vec3(0.0), top, flap, wing);
    EX[i] = place(vec3(1.0, 0.0, 0.0), top, flap, wing) - O[i];
    EY[i] = place(vec3(0.0, 1.0, 0.0), top, flap, wing) - O[i];
  }

  vec3 ro = vec3(0.0, 0.0, CAM);
  vec3 rd = normalize(vec3((st - 0.5) * vec2(W, 1.0), 0.0) - ro);
  float px = 0.003;

  // the two nearest layers, so a crease edge blends with the layer behind it, not the background
  float t1 = 1e4, t2 = 1e4, k1 = -1.0, k2 = -1.0;
  vec2 s1 = vec2(0.0), s2 = vec2(0.0);
  vec3 n1 = vec3(0.0), n2 = vec3(0.0);
  float a1 = 0.0, a2 = 0.0;
  bool f1 = true, f2 = true;
  for (int i = 0; i < 8; i++) {
    bool top = i < 4;
    bool flap = mod(float(i), 4.0) > 1.5;
    bool wing = mod(float(i), 2.0) > 0.5;
    vec3 n = cross(EX[i], EY[i]);
    float den = dot(rd, n);
    if (abs(den) < 1e-4) continue;
    float t = dot(O[i] - ro, n) / den;
    vec3 q = ro + t * rd - O[i];
    vec2 s = vec2(dot(q, EX[i]), dot(q, EY[i]));
    vec2 dd = inside(s, top, flap, wing);
    // pieces are widened by a pixel so neighbours overlap without a seam and the flat sheet covers the frame;
    // between coplanar pieces the one the pixel lies deepest in wins; between stacked ones, the nearer one if it covers it
    float d = min(dd.x, dd.y) + px;
    if (t <= 0.0 || d <= -px) continue;
    // a piece seen edge-on is thinner than a pixel, so it fades instead of aliasing
    float a = smoothstep(-px, px, d) * smoothstep(0.0, 0.1, abs(den));
    vec3 nf = den < 0.0 ? n : -n;
    // a (nearly) coplanar piece never becomes the layer behind, or it would hide the real one where both end on a crease
    if (abs(t - t1) < 0.01) {
      bool take = abs(t - t1) < 1e-4 ? dd.y > k1 : (t < t1 ? dd.y > 0.0 || dd.y > k1 : k1 < 0.0 && dd.y > k1);
      if (take) { t1 = t; s1 = s; n1 = nf; k1 = dd.y; f1 = den < 0.0; }
      a1 = max(a1, a);
    } else if (t < t1) {
      t2 = t1; s2 = s1; n2 = n1; a2 = a1; f2 = f1; k2 = k1;
      t1 = t; s1 = s; n1 = nf; a1 = a; k1 = dd.y; f1 = den < 0.0;
    } else if (abs(t - t2) < 0.01) {
      bool take = abs(t - t2) < 1e-4 ? dd.y > k2 : (t < t2 ? dd.y > 0.0 || dd.y > k2 : k2 < 0.0 && dd.y > k2);
      if (take) { t2 = t; s2 = s; n2 = nf; k2 = dd.y; f2 = den < 0.0; }
      a2 = max(a2, a);
    } else if (t < t2) {
      t2 = t; s2 = s; n2 = nf; a2 = a; f2 = den < 0.0; k2 = dd.y;
    }
  }

  vec4 bg = getToColor(uv);
  // the plane's shadow on the incoming image, seen as a table that stays below it as it flies off
  vec3 g = ro + rd * (CAM - shift.z + 0.6) / -rd.z;
  float sh = 0.0;
  for (int i = 0; i < 8; i++) {
    if (a1 >= 1.0) break;
    bool top = i < 4;
    bool flap = mod(float(i), 4.0) > 1.5;
    bool wing = mod(float(i), 2.0) > 0.5;
    vec3 n = cross(EX[i], EY[i]);
    float den = dot(LIGHT, n);
    if (abs(den) < 1e-4) continue;
    float t = dot(O[i] - g, n) / den;
    vec3 q = g + t * LIGHT - O[i];
    vec2 dd = inside(vec2(dot(q, EX[i]), dot(q, EY[i])), top, flap, wing);
    // the penumbra widens with the height above the table; creases are overlapped so they cast no light seams
    float w = 0.005 + 0.03 * t;
    if (t > 0.0) sh = max(sh, smoothstep(-w, w, min(dd.x, dd.y + 2.0 * w)) / (1.0 + t));
  }
  bg.rgb *= 1.0 - 0.6 * shading * sh * (1.0 - e4);

  vec4 col = bg;
  if (a2 > 0.0) col = mix(col, shadeFace(s2, n2, f2), a2);
  if (a1 > 0.0) col = mix(col, shadeFace(s1, n1, f1), a1);
  return col;
}
