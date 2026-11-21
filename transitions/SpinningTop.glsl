// Author: gre
// License: MIT
// Description: The outgoing image curls round into a spinning top standing on its point, which whirls faster and faster with its picture streaking round it, wobbles, then skitters off out of the frame, uncovering the incoming image under its shadow
// Tags: 3d, spin, curl, shadow

// @range(0, 1) Lean of the wobble while the top spins
uniform float wobble; // = 0.5
// @range(2, 12) Turns of the top before it leaves
uniform float turns; // = 7.0

const float PI = 3.14159265;
const float CAM = 3.0;
const float GROUND = 0.07;

float a1, c1, rMax, hSheet, spin, tilt, prec, wRow;
vec3 shift;

// radius of the top along its height, 0 at the point, 1 at the belly, then a shoulder into the stem
float profile(float v) {
  v = clamp(v, 0.0, 1.0);
  float s = min(v / 0.6, 1.0);
  return max(mix(1.0 - pow(1.0 - s, 1.6), 0.08, smoothstep(0.58, 0.85, v)), 0.02);
}

// the point and the stem narrow ahead of the belly so the half-curled sheet doesn't read as a jar
float widthAt(float v) {
  float e = clamp(abs(v - 0.6) / 0.6, 0.0, 1.0);
  return mix(1.0, 2.0 * PI * rMax * profile(v) / ratio, 1.0 - pow(1.0 - a1, 1.0 + 3.0 * e));
}

// atan(q.x, q.y) with comparisons for the quadrant: some backends turn atan(-0.0, y) into -pi, and a series
// for small angles, where their atan is too coarse once scaled by the bend radius
float angleOf(vec2 q) {
  vec2 a = abs(q);
  float b;
  if (a.x < 0.25 * a.y) {
    float w = a.x / a.y;
    float w2 = w * w;
    b = w * (1.0 - w2 * (1.0 / 3.0 - w2 * (0.2 - w2 / 7.0)));
  } else if (a.x < a.y) {
    b = atan(a.x / a.y);
  } else {
    b = 0.5 * PI - atan(a.y / max(a.x, 1e-9));
  }
  if (q.y < 0.0) b = PI - b;
  return q.x < 0.0 ? -b : b;
}

vec3 rotY(vec3 p, float a) {
  float c = cos(a), s = sin(a);
  return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

// (arc along the row, height on the sheet 0..1, distance to the sheet)
vec3 unbend(vec3 p) {
  float base = -0.5 + GROUND * a1;
  vec3 apex = vec3(0.0, base, -rMax * a1);
  vec3 q = rotY(p - shift - apex, -prec);
  float c = cos(tilt), s = sin(tilt);
  q.xy = mat2(c, -s, s, c) * q.xy;
  q = rotY(q, prec + spin) + apex;
  float v = (q.y - base) / hSheet;
  wRow = widthAt(v);
  float k = c1 * 2.0 * PI / (ratio * wRow);
  float zf = -a1 * rMax * (1.0 - profile(v));
  // radial distance overestimates the true one by up to the steepest slope of the profile
  float sl = a1 * rMax * 5.2 / hSheet;
  float lip = inversesqrt(1.0 + sl * sl);
  if (k < 1e-3) return vec3(q.x, v, (q.z - zf) * lip);
  float R = 1.0 / k;
  vec2 d = vec2(q.x, q.z - zf + R);
  return vec3(angleOf(d) * R, v, (length(d) - R) * lip);
}

float sdf(vec3 p) {
  vec3 u = unbend(p);
  vec2 o = max(abs(u.xy - vec2(0.0, 0.5)) - vec2(0.5 * ratio * wRow, 0.5), 0.0) * vec2(1.0, hSheet);
  return length(vec3(o, u.z));
}

// once the row is closed, both sides of the seam fade to the same colour
vec4 sheet(float s, float v) {
  float o = s < 0.5 ? s + 1.0 : s - 1.0;
  float m = 0.5 * (1.0 - smoothstep(0.0, 0.05, min(s, 1.0 - s))) * smoothstep(0.9, 1.0, c1);
  vec2 inset = vec2(0.004 * m, 0.0);
  return mix(
    getFromColor(clamp(vec2(s, v), inset, 1.0 - inset)),
    getFromColor(clamp(vec2(o, v), inset, 1.0 - inset)), m);
}

vec4 transition(vec2 uv) {
  float t = progress;
  a1 = smoothstep(0.0, 0.3, t);
  c1 = min(1.0, 1.06 * a1);
  float a2 = smoothstep(0.2, 0.75, t);
  float a3 = smoothstep(0.6, 1.0, t);
  // sized from the shorter side so a portrait frame still gives a squat top
  rMax = 0.27 * min(1.0, 1.4 * ratio);
  hSheet = mix(1.0, 2.6 * rMax, a1);
  spin = turns * 2.0 * PI * a2 * a2 + 8.0 * a3;
  float x2 = clamp((t - 0.2) / 0.55, 0.0, 1.0);
  float x3 = clamp((t - 0.6) / 0.4, 0.0, 1.0);
  float da2 = 6.0 * x2 * (1.0 - x2) / 0.55;
  float da3 = 6.0 * x3 * (1.0 - x3) / 0.4;
  float omega = turns * 4.0 * PI * a2 * da2 + 8.0 * da3;
  prec = 9.0 * a2 * a2 + 3.0 * a3;
  tilt = wobble * 0.3 * a2 * a2 * (1.0 - a3) + 0.45 * a3 * a3;
  float hop = 0.05 * abs(sin(a3 * 3.0 * PI)) * (1.0 - a3);
  shift = vec3(a3 * a3 * (0.5 * ratio + 2.5 * rMax + 0.5), hop, 0.0);

  // any eye position leaves the flat frame exact; a raised one looks down onto the shoulder
  vec3 ro = vec3(0.0, 1.1, CAM);
  vec3 rd = normalize(vec3((uv - 0.5) * vec2(ratio, 1.0), 0.0) - ro);
  float hd = (CAM - 0.6) / -rd.z;
  float hEnd = (CAM + 1.2) / -rd.z;
  float minD = 1e3;
  bool hit = false;
  for (int i = 0; i < 100; i++) {
    float d = sdf(ro + rd * hd);
    minD = min(minD, d);
    if (d < 4e-4) { hit = true; break; }
    hd += d * 0.9;
    if (hd > hEnd) break;
  }

  vec4 bg = getToColor(uv);
  float shadowAmt = a1 * (1.0 - a3);
  vec3 foot = vec3(shift.x, -0.5 + GROUND * a1, -rMax);
  vec2 fs = (ro + (foot - ro) * (CAM / (CAM - foot.z))).xy;
  vec2 fd = ((uv - 0.5) * vec2(ratio, 1.0) - fs - vec2(0.5 * rMax, 0.0)) / vec2(rMax * 1.4, 0.04);
  float contact = exp(-dot(fd, fd)) / (1.0 + 20.0 * shift.y);
  bg.rgb *= 1.0 - (0.25 * (1.0 - smoothstep(0.0, 0.08, minD)) + 0.5 * contact) * shadowAmt;
  if (!hit) return bg;
  // converge past the loose march tolerance so every backend lands on the same texel
  for (int j = 0; j < 3; j++) hd += sdf(ro + rd * hd);

  vec3 p = ro + rd * hd;
  vec3 u = unbend(p);
  float w = wRow;
  vec2 e = vec2(1e-3, 0.0);
  vec3 n = normalize(vec3(
    unbend(p + e.xyy).z - unbend(p - e.xyy).z,
    unbend(p + e.yxy).z - unbend(p - e.yxy).z,
    unbend(p + e.yyx).z - unbend(p - e.yyx).z));
  bool front = dot(n, rd) < 0.0;
  if (!front) n = -n;
  float s0 = u.x / (ratio * w) + 0.5;
  // a trail behind each point, brightest at its head, so the spin reads in a still frame
  float blur = min(omega / (2.0 * PI) * 0.012, 0.4) * smoothstep(0.9, 1.0, c1);
  vec4 c = vec4(0.0);
  float tw = 0.0;
  for (int j = 0; j < 12; j++) {
    float f = float(j) / 11.0;
    float wt = 1.0 - 0.8 * f;
    float s = s0 - blur * f;
    s = s < 0.0 ? s + 1.0 : s;
    c += sheet(s, u.y) * wt;
    tw += wt;
    if (blur == 0.0) break;
  }
  c /= tw;
  vec3 L = normalize(vec3(-0.5, 0.7, 1.0));
  float diff = max(dot(n, L), 0.0);
  float spec = pow(max(dot(reflect(-L, n), -rd), 0.0), 24.0);
  float shade = mix(1.0, 0.45 + 0.7 * diff, a1);
  if (front) c.rgb = c.rgb * shade + 0.35 * spec * a1 * c.a;
  else c.rgb *= 0.35 * shade;
  float aa = 1.5 / 200.0;
  float ex = mix(1.0, smoothstep(0.0, aa, 0.5 * ratio * w - abs(u.x)), c1 * (1.0 - c1) * 4.0);
  float ey = mix(1.0, smoothstep(0.0, aa / hSheet, 0.5 - abs(u.y - 0.5)), min(a1 * 4.0, 1.0));
  return mix(bg, c, min(ex, ey));
}
