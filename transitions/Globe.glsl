// Author: gre
// License: MIT
// Description: The outgoing image curls round into a shaded globe like a world map over a soft blurred backdrop; the globe spins half a turn to bring the incoming image round from its far side, which then unrolls flat to fill the frame
// Tags: 3d, sphere, globe, spin, wrap

// @range(0.25, 0.5) Radius of the globe, relative to the shorter side of the frame
uniform float size; // = 0.42
// @range(0, 1) Strength of the light and shading on the globe
uniform float shading; // = 0.7

const float PI = 3.14159265;
const float D = 2.0;
const vec3 LIGHT = vec3(-0.45, 0.5, -0.74) / 1.00005;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// series near 0: atan and asin are coarse at small arguments on some targets, and the
// globe starts with a huge radius where these angles are tiny
float arc(float y, float x) {
  float q = y / max(x, 1e-7);
  float q2 = q * q;
  return abs(q) < 0.25 ? q * (1.0 - q2 * (1.0 / 3.0 - q2 * (0.2 - q2 / 7.0))) : atan(y, max(x, 1e-7));
}

float lat(float s) {
  float s2 = s * s;
  return abs(s) < 0.25 ? s * (1.0 + s2 * (1.0 / 6.0 + s2 * (0.075 + s2 * 0.0446429))) : asin(clamp(s, -1.0, 1.0));
}

vec4 backdrop(vec2 uv, float w, float s) {
  vec2 q = 0.5 + (uv - 0.5) * (1.0 - 0.1 * w);
  vec4 c = vec4(0.0);
  vec2 g = vec2(1.0, 0.0);
  // golden-angle spiral
  mat2 turn = mat2(-0.73736887, 0.67549029, -0.67549029, -0.73736887);
  for (int i = 0; i < 24; i++) {
    vec2 o = 0.04 * w * sqrt((float(i) + 0.5) / 24.0) * g * vec2(1.0 / ratio, 1.0);
    vec4 x = mix(getFromColor(mirror(q + o)), getToColor(mirror(q + o)), s);
    c += vec4(x.rgb * x.a, x.a);
    g = turn * g;
  }
  return vec4(c.rgb / max(c.a, 1e-6) * (1.0 - 0.4 * w), c.a / 24.0);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // the globe's apparent size shrinks about linearly with w
  float w = min(smoothstep(0.0, 0.48, p), 1.0 - smoothstep(0.52, 1.0, p));
  float spin = smoothstep(0.2, 0.8, p);
  float r1 = size * min(ratio, 1.0);
  float wc = max(w, 1e-4);
  float R = r1 / wc;
  // squeeze so that at full curl each image covers exactly one hemisphere
  float ax = mix(1.0, ratio / (PI * r1), w);
  float a = PI * spin;
  // once turning, the images stretch round their hemispheres so no gap opens between them
  float closed = smoothstep(0.0, 0.6, min(a, PI - a));
  float L = mix(0.5 * ratio * wc / (r1 * ax), 0.5 * PI, closed);
  float ay = mix(1.0, 1.0 / (PI * r1), w);

  vec2 sc = (uv - 0.5) * vec2(ratio, 1.0);
  vec3 d = normalize(vec3(sc, D));
  // sphere centre at (0, 0, D + R) with its front point at z = D; |o - c|^2 - R^2 without cancellation
  float b = -(D + R) * d.z;
  float cc = D * D + 2.0 * D * R;
  float disc = max(b * b - cc, 0.0);
  float t = cc / (-b + sqrt(disc));
  vec3 h = d * t;
  vec3 n = vec3(h.xy, h.z - D - R) / R;
  float cs = cos(a), sn = sin(a);
  vec3 m = vec3(cs * n.x + sn * n.z, n.y, -sn * n.x + cs * n.z);
  bool back = m.z > 0.0;
  float lon = back ? -arc(m.x, m.z) : arc(m.x, -m.z);
  vec2 tuv = vec2(0.5 * lon / L, R * lat(m.y) * ay) + 0.5;

  float rs = D * R / sqrt(cc);
  float ds = length(sc);
  float aa = 0.003 * min(1.0, 20.0 * w) + 1e-6;
  // no edge fade along the seam once the two images meet there
  vec2 e = min(tuv, 1.0 - tuv) * vec2(ratio, 1.0) + vec2(closed * aa, 0.0);
  float cov = clamp(0.5 + min(e.x, e.y) / aa, 0.0, 1.0) * clamp(0.5 + (rs - ds) / aa, 0.0, 1.0);

  vec4 bg = cov < 1.0 ? backdrop(uv, w, spin) : vec4(0.0);
  float shadow = 1.0 - smoothstep(0.85 * rs, 1.3 * rs, length(sc - vec2(0.03, -0.05) * rs));
  bg.rgb *= 1.0 - 0.45 * w * shadow;

  vec4 col = back ? getToColor(clamp(tuv, 0.0, 1.0)) : getFromColor(clamp(tuv, 0.0, 1.0));
  float diff = max(dot(n, LIGHT), 0.0) / -LIGHT.z;
  float k = shading * w;
  float seam = 1.0 - 0.6 * k * (1.0 - smoothstep(0.0, 0.03, abs(m.z)));
  float spec = pow(max(dot(reflect(-LIGHT, n), -d), 0.0), 30.0);
  col.rgb = col.rgb * mix(1.0, 0.2 + 0.85 * diff, k) * seam + 0.3 * k * spec;
  vec4 o = mix(vec4(bg.rgb * bg.a, bg.a), vec4(col.rgb * col.a, col.a), cov);
  return vec4(o.rgb / max(o.a, 1e-6), o.a);
}
