// Author: gre
// License: MIT
// Description: The incoming image wells up from one point as a round bubble while the outgoing one streams away along curved field lines and drains into a second point, both pictures flowing like a field between two charges
// Tags: conformal, flow, warp, bubble, mobius

// @param Point the incoming image wells up from
uniform vec2 source; // = vec2(0.1, 0.5)
// @param Point the outgoing image drains into
uniform vec2 sink; // = vec2(0.9, 0.5)
// @range(0.5, 4) How far the pictures travel along the field lines
uniform float flow; // = 1.4
// @range(-2.5, 2.5) Spin of the flow around the two points, 0 for straight field lines
uniform float swirl; // = 0.0
// @range(0, 1) Shadow and highlight along the rim of the bubble
uniform float shading; // = 0.6

vec2 cmul(vec2 a, vec2 b) { return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }
vec2 cdiv(vec2 a, vec2 b) { return vec2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / max(dot(b, b), 1e-12); }

// the outer field lines bring in content from beyond the frame
vec2 mirrorUv(vec2 uv) { return 1.0 - abs(1.0 - mod(uv, 2.0)); }

// w = (z-A)/(z-B) sends source/sink to 0/infinity: scaling w slides points along the circular field lines
vec2 unflow(vec2 w, vec2 A, vec2 B, vec2 asp, float s, float a) {
  vec2 v = cmul(w, exp(s) * vec2(cos(a), sin(a)));
  return mirrorUv(cdiv(A - cmul(B, v), vec2(1.0, 0.0) - v) / asp + 0.5);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 A = (source - 0.5) * asp, B = (sink - 0.5) * asp;
  if (length(B - A) < 0.01) B = A + vec2(0.01, 0.0);
  float ab = length(B - A);
  vec2 z = (uv - 0.5) * asp;
  vec2 w = cdiv(z - A, z - B);

  float e = t * t * (3.0 - 2.0 * t);
  // the outer field lines loop through off-frame space: slow them down so little of it streams in;
  // a spin above ~2.76 would let some point of w * exp(i a h) reach 1, a pole of unflow
  float h = 0.5 - 0.5 * w.x * inversesqrt(max(dot(w, w), 1e-12));
  float a = clamp(swirl, -2.5, 2.5) * h;
  vec4 from = getFromColor(unflow(w, A, B, asp, -flow * h * e, -a * e));
  vec4 to = getToColor(unflow(w, A, B, asp, flow * h * (1.0 - e), a * (1.0 - e)));

  // seam: the Apollonius circle |w| = k, k = (t / (1 - t))^1.8, written with q = k^2 / (1 + k^2) so nothing overflows
  float p0 = pow(t, 3.6), p1 = pow(1.0 - t, 3.6);
  float q = p0 / (p0 + p1);
  vec2 za = z - A, zb = z - B;
  float d = ((1.0 - q) * dot(za, za) - q * dot(zb, zb))
    / (length((1.0 - 2.0 * q) * z - (1.0 - q) * A + q * B) + sqrt(q * (1.0 - q)) * ab);
  float radius = sqrt(q * (1.0 - q)) * ab / max(abs(1.0 - 2.0 * q), 1e-4);
  float rim = clamp(0.3 * radius, 1e-4, 0.07);

  // the bias keeps a pixel exactly on the source or sink on the right side at both ends
  float m = smoothstep(-0.003, 0.003, d + 0.003 * (1.0 - 2.0 * t));
  float env = shading * 4.0 * t * (1.0 - t);
  from.rgb *= 1.0 - 0.55 * env * exp(-max(d, 0.0) / rim);
  to.rgb += 0.3 * env * exp(-d * d / (0.08 * rim * rim)) * (1.0 - m);
  return mix(to, from, m);
}
