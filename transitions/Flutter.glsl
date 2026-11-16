// Author: gre
// License: MIT
// Description: The outgoing image is let go and falls like a sheet of paper: it tips back and sinks while gliding from side to side, its leading edge dipping and rising at the end of each swing, until it drops out of the bottom of the frame, casting a shadow on the incoming image
// Tags: fall, paper, sway, 3d, gravity, shadow

// @range(0.5, 3) Number of side-to-side swings
uniform float swings; // = 1.5
// @range(0, 0.5) Width of each swing, in frame heights
uniform float sway; // = 0.3
// @range(0, 1) Shading of the sheet and darkness of its shadow
uniform float shading; // = 0.7

const float PI = 3.141592653589793;
const vec3 EYE = vec3(0.0, 0.0, -2.0);
const float TILT = 1.05;
const float BANK = 0.35;
const float YAW = 0.45;
const float BEND = 0.07;
const float DEPTH = 0.65;

mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c); }
mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }

mat3 pose(float env, float side, float vel) {
  return rotY(YAW * vel) * rotX(TILT * env) * rotY(BANK * side);
}

// offset of the bent sheet toward the viewer at x, and its slope
vec2 curl(float x, float env) {
  float w = 0.5 * ratio;
  float u = clamp(x / w, -1.0, 1.0);
  float a = BEND * env * min(ratio, 1.0);
  return vec2(a * (u * u - 1.0 / 3.0), 2.0 * a * u / w);
}

// sheet coordinates where the ray o + k d meets the bent sheet, and k
vec3 onSheet(vec3 o, vec3 d, vec3 C, mat3 R, float env) {
  vec3 n = R[2];
  float dn = dot(d, n);
  dn = abs(dn) < 1e-4 ? 1e-4 : dn;
  vec3 q = vec3(0.0);
  for (int i = 0; i < 3; i++) {
    float k = dot(C - n * curl(q.x, env).x - o, n) / dn;
    vec3 h = o + k * d - C;
    q = vec3(dot(h, R[0]), dot(h, R[1]), k);
  }
  return q;
}

float sheetMask(vec3 q, vec2 aa) {
  vec2 e = abs(q.xy) - vec2(0.5 * ratio, 0.5);
  return (1.0 - smoothstep(-aa.x, aa.x, e.x)) * (1.0 - smoothstep(-aa.y, aa.y, e.y)) * step(0.0, q.z);
}

vec4 sheetColor(vec3 q) {
  return getFromColor(clamp(vec2(q.x / ratio, q.y) + 0.5, 0.0, 1.0));
}

vec4 transition(vec2 uv) {
  float t = progress;
  float env = smoothstep(0.0, 0.4, t);
  float ph = 2.0 * PI * swings * t;
  float side = sin(ph) * env;
  float vel = cos(ph) * env;
  // the glide follows a pendulum arc, rising at the end of each swing
  float lift = 0.35 * sway;
  float focal = -EYE.z;

  // fall far enough that every corner of the end pose leaves the frame
  mat3 R1 = pose(1.0, sin(2.0 * PI * swings), cos(2.0 * PI * swings));
  float drop = 0.0;
  for (int i = 0; i < 4; i++) {
    vec2 c = vec2(i < 2 ? -0.5 * ratio : 0.5 * ratio, mod(float(i), 2.0) - 0.5);
    vec3 o = R1 * vec3(c, 0.0) - R1[2] * BEND * min(ratio, 1.0);
    drop = max(drop, 0.51 * (focal + DEPTH + o.z) / focal + o.y);
  }
  drop += lift;

  vec3 C = vec3(
    sway * side,
    -drop * t * t * (0.3 + 0.7 * t) + lift * side * side,
    DEPTH * (0.45 * env + 0.55 * t * t)
  );
  mat3 R = pose(env, side, vel);

  vec2 p = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec3 d = vec3(p, focal);
  vec3 q = onSheet(EYE, d, C, R, env);
  // edge width in sheet units, wider across the tilt that foreshortens it
  vec2 aa = (0.0001 + 0.0025 * env * (1.0 + C.z / focal)) * vec2(1.0, 1.0 / cos(TILT * env));
  float m = sheetMask(q, aa);

  float gap = 1.0 - 0.7 * t;
  vec3 qs = onSheet(EYE, vec3(p - vec2(0.07, -0.14) * gap * env, focal), C, R, env);
  float sh = sheetMask(qs, vec2(0.01 + 0.1 * gap)) * sheetColor(qs).a * env;
  vec4 bg = getToColor(uv);
  bg.rgb *= 1.0 - 0.75 * shading * sh;

  vec4 img = sheetColor(q);
  vec3 N = normalize(R * vec3(-curl(q.x, env).y, 0.0, -1.0));
  vec3 K = normalize(vec3(-0.4, 0.3, -1.0));
  float lit = min(max(dot(N, K), 0.0) / -K.z, 1.0);
  float spec = pow(max(dot(N, normalize(K + normalize(-d))), 0.0), 30.0);
  img.rgb = min(img.rgb * mix(1.0, lit, shading * env) + 0.3 * shading * env * spec, 1.0);
  return mix(bg, img, m);
}
