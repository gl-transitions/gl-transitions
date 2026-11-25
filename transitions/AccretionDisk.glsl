// Author: gre
// License: MIT
// Description: A black hole opens in the outgoing picture and shears it into a glowing disk of its own colors; the camera swings down to the edge of the disk, whose far side is seen bent up over the dark shadow, with the incoming picture as the sky warped all around; the disk is swallowed, the hole evaporates and the sky straightens out
// Tags: space, black-hole, lens, 3d, distort

// @range(0, 1.45) How far the camera swings down towards the plane of the disk
uniform float tilt; // = 1.36
// @range(0.03, 0.14) Radius of the hole, in frame heights
uniform float holeSize; // = 0.085
// @range(0, 1.5) Heat of the inner disk
uniform float glow; // = 0.8
// @color Color of the hole
uniform vec4 hole; // = vec4(0.0, 0.0, 0.0, 1.0)

const int STEPS = 40;
const float H = 0.17;
const float DIST = 1.6;

float heating() {
  return smoothstep(0.06, 0.4, progress);
}

vec2 mirrored(vec2 u) {
  return 1.0 - abs(1.0 - mod(u, 2.0));
}

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

vec2 turn(vec2 v, float a) {
  return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 material(vec2 d, float r, vec2 asp) {
  float hot = heating();
  vec2 w = turn(d, -2.2 * hot * progress * pow(max(r, 0.06), -1.1));
  vec2 b = 2.0 * w / asp;
  b *= b;
  // a soft cap keeps the disk within the picture, which would repeat past its edges
  w /= pow(1.0 + hot * dot(b, b), 0.25);
  return pm(getFromColor(mirrored(w / asp + 0.5)));
}

float diskCover(float r, float rs, float rOut) {
  return smoothstep(2.4 * rs - 1e-4, 3.1 * rs + 1e-4, r + step(rs, 0.0)) * (1.0 - smoothstep(0.82 * rOut, rOut, r)) * smoothstep(0.001, 0.02, rOut);
}

vec4 disk(vec2 d, float rs, float rOut, float st, vec2 asp) {
  float hot = heating();
  float r = length(d);
  float inner = 2.6 * rs;
  // the shear packs the picture along the radius
  vec2 e = 0.0035 * hot * d / max(r, 1e-4);
  vec4 c = 0.25 * (material(d - 1.5 * e, r - 1.5 * length(e), asp) + material(d - 0.5 * e, r - 0.5 * length(e), asp)
    + material(d + 0.5 * e, r + 0.5 * length(e), asp) + material(d + 1.5 * e, r + 1.5 * length(e), asp));
  vec2 s = turn(d / max(r, 1e-4), -2.0 * progress * pow(max(r, 0.06), -1.1));
  float lanes = noise(vec2(r * 46.0, 7.0)) * 0.6 + 0.4 * noise(vec2(r * 95.0, 3.0));
  lanes *= 0.75 + 0.5 * noise(s * 4.0 + 8.0 + r * 9.0);
  c.rgb *= mix(1.0, 0.45 + 1.3 * lanes, hot * 0.6);
  // Doppler beaming: the side turning towards the camera is brighter
  float beam = 1.0 + 0.55 * st * hot * d.x / max(r, 0.05);
  float heat = hot * glow * exp(-max(r - inner, 0.0) * 5.5);
  c.rgb = c.rgb * beam + heat * (c.rgb + 0.25 * c.a) * vec3(1.9, 1.1, 0.5) * beam * (0.4 + lanes);
  return c;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float lean = tilt * smoothstep(0.04, 0.55, p);
  float rs = holeSize * min(1.0, 0.35 + 0.65 * ratio) * smoothstep(0.02, 0.4, p) * (1.0 - smoothstep(0.62, 1.0, p));
  float hot = heating();
  float rOut = max(1e-3, 2.3 * pow(1.0 - smoothstep(0.12, 0.92, p), 1.1) - 0.12 * smoothstep(0.6, 0.95, p) + 6.0 * (1.0 - smoothstep(0.0, 0.16, p)));
  float ct = cos(lean);
  float st = sin(lean);
  float roll = 0.22 * smoothstep(0.1, 0.5, p) * (1.0 - smoothstep(0.65, 1.0, p));
  vec2 s = turn((uv - 0.5) * asp, roll);
  // the disk lies in z = 0 and the camera swings down towards its plane
  vec3 ex = vec3(1.0, 0.0, 0.0);
  vec3 ey = vec3(0.0, ct, st);
  vec3 ez = vec3(0.0, -st, ct);
  // a ray stays in the plane of the hole and its own direction
  float sl = max(length(s), 1e-4);
  vec3 et = (ex * s.x + ey * s.y) / sl;
  float u = 1.0 / DIST;
  float v = u * DIST / sl;
  float invB2 = u * u * (1.0 - rs * u) + v * v;
  // angle at which the ray crosses the disk, as a direction
  vec2 cr = normalize(vec2(-et.z, ez.z));

  float escaped = 0.0;
  // z = 1 once the ray has crossed the disk
  vec3 hitA = vec3(0.0);
  vec3 hitB = vec3(0.0);
  vec3 dir = -ez;
  float cH = cos(H);
  float sH = sin(H);
  for (int i = 0; i < STEPS; i++) {
    vec2 f = vec2(cos(float(i) * H), sin(float(i) * H));
    // u = 1 / r follows u'' = -u + 1.5 rs u^2: the first part is an exact rotation
    v += 0.75 * H * rs * u * u;
    float un = u * cH + v * sH;
    float vn = v * cH - u * sH;
    vec2 g = vec2(f.x * cr.x + f.y * cr.y, f.x * cr.y - f.y * cr.x);
    if (g.x < 0.0) g = -g;
    float uc = u * g.x + v * g.y;
    if (g.y > 0.0 && g.y <= sH && uc > 0.0) {
      vec2 at = vec2(f.x * g.x - f.y * g.y, f.y * g.x + f.x * g.y) / uc;
      vec3 hit = vec3(ez.x * at.x + et.x * at.y, ez.y * at.x + et.y * at.y, 1.0);
      if (hitA.z < 0.5) hitA = hit;
      else if (hitB.z < 0.5) hitB = hit;
    }
    if (un <= 0.0) {
      vec2 e = normalize(vec2(-v, u));
      dir = ez * (f.x * e.x - f.y * e.y) + et * (f.y * e.x + f.x * e.y);
      escaped = 1.0;
      break;
    }
    u = un;
    v = vn + 0.75 * H * rs * u * u;
    if (u * rs > 1.0) break;
  }

  vec3 cd = vec3(dot(dir, ex), dot(dir, ey), -dot(dir, ez));
  float far = 0.55 * length(asp) / DIST;
  float z1 = 1.0 / sqrt(1.0 + far * far);
  float q = max(1.0 - cd.z / z1, 0.0);
  // levels off past the corners, so that light bent backwards still lands on the picture
  float rho = cd.z > z1 ? length(cd.xy) / cd.z : far + 1.0 / sqrt(1.0 - z1 * z1) * q / (1.0 + 12.0 * q);
  vec2 sk = turn(normalize(cd.xy + 1e-6) * rho * DIST, -roll);
  vec4 sky = pm(getToColor(mirrored(sk / asp + 0.5)));
  float shade = smoothstep(0.1, 0.4, p) * (1.0 - smoothstep(0.6, 0.95, p));
  sky.rgb *= 1.0 - 0.28 * shade;
  // light that winds round the hole is a blur of the whole sky
  vec4 blur = pm(0.5 * (getToColor(vec2(0.3, 0.6)) + getToColor(vec2(0.7, 0.4))));
  sky = mix(vec4(0.35 * blur.rgb, blur.a), sky, smoothstep(-0.4, 0.5, cd.z));
  // b is conserved along the ray, and critical at sqrt(6.75) rs
  float b = 1.0 / sqrt(max(invB2, 1e-6));
  float bc = 2.598 * rs;
  float ring = glow * hot * exp(-max(b - bc, 0.0) / (0.004 + 0.25 * rs)) * smoothstep(0.0, 0.02, rs);
  sky.rgb += ring * vec3(0.75, 0.5, 0.28) * sky.a;
  float clear = escaped * smoothstep(bc - 0.0015, bc + 0.0015, b + step(rs, 0.0));
  vec4 acc = mix(pm(hole), sky, clear);
  float kA = hitA.z * diskCover(length(hitA.xy), rs, rOut);
  float kB = hitB.z * diskCover(length(hitB.xy), rs, rOut);
  if (kB > 0.0) acc = mix(acc, disk(hitB.xy, rs, rOut, st, asp), kB);
  if (kA > 0.0) acc = mix(acc, disk(hitA.xy, rs, rOut, st, asp), kA);
  return acc.a > 0.0 ? vec4(min(acc.rgb / acc.a, 1.0), acc.a) : vec4(0.0);
}
