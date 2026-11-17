// Author: gre
// License: MIT
// Description: The outgoing image spans the frame like a plank held at its sides: it sags in the middle under its own weight, a jagged crack runs up from the bottom, and the two halves snap apart, swing down around their outer top corners and drop out of the frame, revealing the incoming image under their shadow
// Tags: physical, gravity, break, crack, fall

// @range(0, 0.2) How far the middle sags before it cracks
uniform float sag; // = 0.12
// @range(0, 0.1) Sideways jitter of the jagged crack
uniform float jaggedness; // = 0.035
// @color Color of the shadow cast on the incoming image
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.5)

const float PI = 3.141592653589793;
const float BREAK = 0.34;
const float AA = 0.002;

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

float jag(float y, float freq, float seed) {
  float k = y * freq;
  return mix(hash(floor(k) + seed), hash(floor(k) + seed + 1.0), fract(k)) - 0.5;
}

float crackX(float y) {
  return 0.5 * ratio + jaggedness * (jag(y, 7.0, 3.0) + 0.4 * jag(y, 23.0, 41.0));
}

// p is mirrored for the right half, so both halves hinge on their top corner at x = 0
vec2 toPiece(vec2 p, mat2 rot, float fall, float bend) {
  vec2 q = rot * (p + vec2(0.0, fall - 1.0)) + vec2(0.0, 1.0);
  q.y += bend * sin(PI * clamp(q.x / ratio, 0.0, 1.0));
  return q;
}

float toCrack(vec2 q, float side) {
  float c = crackX(q.y);
  return (side > 0.0 ? ratio - c : c) - q.x;
}

// outer edges pushed out by one AA width so the halves tile the frame exactly at rest
float cover(vec2 q, float e, float w) {
  vec2 d = min(q, vec2(ratio, 1.0) - q);
  return clamp(min(min(d.x, d.y), e) / w + 1.0, 0.0, 1.0);
}

vec4 shade(vec2 q, float e, float side, float sa, float front, float t) {
  vec4 col = getFromColor(vec2(side > 0.0 ? 1.0 - q.x / ratio : q.x / ratio, q.y));
  float crack = (1.0 - smoothstep(0.0, 0.005, e)) * (1.0 - smoothstep(front - 0.05, front, q.y));
  col.rgb *= (1.0 - 0.75 * crack * (1.0 - smoothstep(0.0, 0.08, t))) * (1.0 - 0.3 * sa * smoothstep(0.0, 0.5 * ratio, q.x));
  return col;
}

vec4 transition(vec2 uv) {
  vec2 p = vec2(uv.x * ratio, uv.y);
  vec2 m = vec2(ratio - p.x, p.y);
  float load = smoothstep(0.0, BREAK, progress);
  float t = clamp((progress - BREAK) / (1.0 - BREAK), 0.0, 1.0);
  float bend = sag * load * (1.0 - smoothstep(0.0, 0.3, t));
  float front = 1.12 * smoothstep(0.12, BREAK, progress) - 0.06;
  float a = 1.1 * t * (0.6 + 0.4 * t);
  float d = max(t - 0.25, 0.0) / 0.75;
  float fall = 1.1 * d * d;
  float ca = cos(a), sa = sin(a);
  mat2 rot = mat2(ca, sa, -sa, ca);

  vec2 ql = toPiece(p, rot, fall, bend);
  vec2 qr = toPiece(m, rot, fall, bend);
  float el = toCrack(ql, -1.0);
  float er = toCrack(qr, 1.0);
  float cl = cover(ql, el, AA);
  float cr = cover(qr, er, AA);

  float lift = 0.3 * load + 0.7 * smoothstep(0.0, 0.4, t);
  vec2 o = vec2(0.015, -0.03) * lift;
  float soft = 0.004 + 0.05 * lift;
  vec2 sl = toPiece(p - o, rot, fall, bend);
  vec2 sr = toPiece(m - vec2(-o.x, o.y), rot, fall, bend);
  float sh = shadow.a * lift * max(cover(sl, toCrack(sl, -1.0), soft), cover(sr, toCrack(sr, 1.0), soft));

  vec4 to = getToColor(uv);
  float alpha = sh + to.a * (1.0 - sh);
  to = vec4((shadow.rgb * sh + to.rgb * to.a * (1.0 - sh)) / max(alpha, 1e-5), alpha);
  vec4 col = mix(to, shade(ql, el, -1.0, sa, front, t), cl);
  return mix(col, shade(qr, er, 1.0, sa, front, t), cr);
}
