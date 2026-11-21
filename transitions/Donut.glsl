// Author: gre
// License: MIT
// Description: The outgoing image curls back into a tube along its longer side, then the tube bends round until its two ends meet in a ring, which rolls away out of the frame like a wheel, uncovering the incoming image
// Tags: torus, curl, roll, 3d

const float PI = 3.14159265;
const float CAM = 3.0;

float k1, k2, ang, shiftX, lift, seamA, seamB;
vec2 size, wrap;
bool portrait;

// local frame: x runs along the longer side, y along the shorter one
vec2 toLocal(vec2 q) { return portrait ? vec2(q.y, -q.x) : q; }

// atan(q.x, q.y); small angles use the series, since some backends' atan is too coarse once scaled by a large bend radius
float angleOf(vec2 q) {
  if (q.y > 0.0 && abs(q.x) < 0.25 * q.y) {
    float w = q.x / q.y;
    float w2 = w * w;
    return w * (1.0 - w2 * (1.0 / 3.0 - w2 * (0.2 - w2 / 7.0)));
  }
  return atan(q.x + 1e-7, q.y);
}

vec3 unbend(vec3 p) {
  p.x -= shiftX;
  float c = cos(ang), s = sin(ang);
  p.xy = mat2(c, s, -s, c) * p.xy;
  p.xy = toLocal(p.xy);
  p.y += lift;
  vec2 st = p.xy;
  if (k2 > 1e-3) {
    float R = 1.0 / k2;
    vec2 q = vec2(p.x, R - p.y);
    st = vec2(angleOf(q) * R, R - length(q));
  }
  vec2 vn = vec2(st.y, p.z);
  if (k1 > 1e-3) {
    float R = 1.0 / k1;
    vec2 q = vec2(st.y, p.z + R);
    vn = vec2(angleOf(q) * R, length(q) - R);
  }
  return vec3(st.x, vn.x, vn.y);
}

float sdf(vec3 p) {
  vec3 u = unbend(p);
  vec2 o = max(abs(u.xy) - 0.5 * size, 0.0);
  return length(vec3(o, u.z));
}

vec4 sheet(vec2 l) {
  // edge pixels are often dark, so a closed seam reads from slightly inside
  vec2 sw = vec2(seamB, seamA);
  vec2 inset = 0.5 * mix(size, wrap, sw) - 0.012 * sw;
  l = clamp(l, -inset, inset);
  vec2 q = portrait ? vec2(-l.y, l.x) : l;
  return getFromColor(q / vec2(ratio, 1.0) + 0.5);
}

// once two edges meet, both sides fade to the same colour so no seam line shows
vec4 sheetSeamless(vec2 l) {
  vec2 d = 0.5 * wrap - abs(l);
  vec2 w = 0.5 * (1.0 - smoothstep(0.0, 0.06, d)) * vec2(seamB, seamA);
  vec2 o = l - sign(l) * wrap;
  return mix(
    mix(sheet(l), sheet(vec2(o.x, l.y)), w.x),
    mix(sheet(vec2(l.x, o.y)), sheet(o), w.x), w.y);
}

vec4 transition(vec2 uv) {
  portrait = ratio < 1.0;
  size = portrait ? vec2(1.0, ratio) : vec2(ratio, 1.0);
  // near-square frames roll the tube over itself, so it stays thinner than the ring and a hole remains
  wrap = vec2(size.x, min(size.y, 0.6 * size.x));
  float t = progress;
  float a1 = smoothstep(0.0, 0.38, t);
  float a2 = smoothstep(0.28, 0.62, t);
  float a3 = smoothstep(0.58, 1.0, t);
  // the ends snap shut instead of creeping together for several frames
  float c1 = min(1.0, 1.06 * a1);
  float c2 = min(1.0, 1.06 * a2);
  seamA = smoothstep(0.8, 1.0, c1);
  seamB = smoothstep(0.8, 1.0, c2);
  k1 = 2.0 * PI / wrap.y * c1;
  k2 = 2.0 * PI / size.x * c2;
  float R = (size.x + wrap.y) / (2.0 * PI);
  shiftX = a3 * a3 * (0.5 * ratio + 1.15 * R + 0.06);
  ang = shiftX / R;
  lift = c2 * size.x / (2.0 * PI);

  vec3 ro = vec3(0.0, 0.0, CAM);
  vec3 rd = normalize(vec3((uv - 0.5) * vec2(ratio, 1.0), 0.0) - ro);
  float h = CAM - 0.5;
  float minD = 1e3;
  bool hit = false;
  for (int i = 0; i < 90; i++) {
    float d = sdf(ro + rd * h);
    minD = min(minD, d);
    if (d < 4e-4) { hit = true; break; }
    h += d * 0.6;
    if (h > CAM + 1.5) break;
  }

  vec4 bg = getToColor(uv);
  bg.rgb *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.12, minD)) * (1.0 - a3 * a3);
  if (!hit) return bg;
  // converge past the loose march tolerance so every backend lands on the same texel
  for (int j = 0; j < 3; j++) h += sdf(ro + rd * h);

  vec3 p = ro + rd * h;
  vec3 u = unbend(p);
  vec2 e = vec2(1e-3, 0.0);
  vec3 n = normalize(vec3(
    unbend(p + e.xyy).z - unbend(p - e.xyy).z,
    unbend(p + e.yxy).z - unbend(p - e.yxy).z,
    unbend(p + e.yyx).z - unbend(p - e.yyx).z));
  vec4 c = sheetSeamless(u.xy);
  bool front = dot(n, rd) < 0.0;
  if (!front) n = -n;
  vec3 L = normalize(vec3(-0.4, 0.6, 1.0));
  float diff = max(dot(n, L), 0.0);
  float spec = pow(max(dot(reflect(-L, n), -rd), 0.0), 30.0);
  float bendAmt = max(a1, a2);
  float shade = mix(1.0, 0.4 + 0.75 * diff, bendAmt);
  if (front) c.rgb = c.rgb * shade + 0.3 * spec * bendAmt;
  else c.rgb *= 0.35 * shade;
  float aa = 1.5 / 200.0;
  // edges sitting on the frame border, or about to close a seam, stay hard
  float ex = mix(1.0, smoothstep(0.0, aa, 0.5 * size.x - abs(u.x)), c2 * (1.0 - c2) * 4.0);
  float ey = mix(1.0, smoothstep(0.0, aa, 0.5 * size.y - abs(u.y)), c1 * (1.0 - c1) * 4.0);
  return mix(bg, c, min(ex, ey));
}
