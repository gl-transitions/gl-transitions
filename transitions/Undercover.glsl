// Author: gre
// License: MIT
// Description: The incoming picture turns up tiny inside the outgoing one, wearing its colors so that no edge shows; it hops closer, crouches, hops again and leaps into the whole frame, then drops the disguise as its true colors spread from the middle
// Tags: playful, hop, blend, color, zoom, reveal

// @param Size of the incoming picture when it first shows up
// @range(0.2, 0.6)
uniform float size; // = 0.34
// @param Height of its hops
// @range(0, 1)
uniform float bounce; // = 0.5

const int TAPS = 14;
const vec2 STEP = vec2(0.9009689, 0.4338837);

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec2 inside(vec2 q) {
  return 1.0 - abs(1.0 - mod(q / vec2(ratio, 1.0) + 0.5, 2.0));
}

float hop(float a, float b) {
  float t = clamp((progress - a) / (b - a), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float m = min(ratio, 1.0);
  float h1 = hop(0.14, 0.23), h2 = hop(0.31, 0.4), h3 = hop(0.48, 0.64);
  float s = size * exp2(-log2(size) * (0.12 * h1 + 0.24 * h2 + 0.64 * h3));
  vec2 c = vec2(0.25, -0.08) * asp;
  c = mix(c, vec2(-0.23, -0.1) * asp, h1);
  c = mix(c, vec2(0.12, -0.04) * asp, h2) * (1.0 - h3);
  // it crouches before each hop
  float down = hop(0.1, 0.13) * (1.0 - hop(0.13, 0.15)) + hop(0.26, 0.29) * (1.0 - hop(0.29, 0.32)) + 1.5 * hop(0.42, 0.46) * (1.0 - hop(0.46, 0.5));
  c.y += bounce * m * (0.6 * h1 * (1.0 - h1) + 0.7 * h2 * (1.0 - h2) + 0.35 * h3 * (1.0 - h3) - 0.06 * s * down);
  float grow = hop(0.52, 0.68);
  float r = s * (0.48 * m * hop(0.0, 0.09) + (0.53 * length(asp) - 0.48 * m) * grow);
  vec2 d = (uv - 0.5) * asp - c;
  vec4 a = getFromColor(uv);
  vec2 w = d / max(r, 1e-4);
  float rho = length(w);
  if (rho >= 1.0) return a;
  a = pm(a);
  vec2 k = vec2(1.0, 1.0 / (1.0 - 0.16 * down)) / s;
  // Poisson kernel over fixed rim points: each picture's rim spread harmonically, without dither
  vec4 F = vec4(0.0), T = vec4(0.0);
  float total = 0.0, sq = 0.0;
  vec2 z = vec2(1.0, 0.0);
  for (int i = 0; i < TAPS; i++) {
    vec2 g = z - w;
    float q = 1.0 / (dot(g, g) + 0.02);
    vec4 t = pm(getToColor(inside(r * z * k)));
    F += q * pm(getFromColor(inside(c + r * z)));
    T += q * t;
    sq += q * dot(t, t);
    total += q;
    z = vec2(z.x * STEP.x - z.y * STEP.y, z.x * STEP.y + z.y * STEP.x);
  }
  F /= total;
  T /= total;
  vec4 b = pm(getToColor(inside(d * k)));
  float spread = max(sq / total - dot(T, T), 0.0);
  // what looks like the rim of the incoming picture is its background: the outgoing picture shows there
  vec4 e = b - T;
  float subject = smoothstep(0.3, 1.1, dot(e, e) / (0.012 + 0.7 * spread));
  subject = mix(subject, 1.0, smoothstep(0.04, 0.11, spread));
  subject = mix(subject, 1.0, smoothstep(0.15, 0.9, grow)) * (1.0 - smoothstep(mix(0.8, 0.95, grow), 1.0, rho));
  float worn = smoothstep(0.0, 0.7, rho + 0.7 - 1.7 * hop(0.6, 1.0)) * (1.0 - hop(0.75, 1.0));
  vec4 col = clamp(mix(a, b + (F - T) * worn, subject), 0.0, 1.0);
  return col.a > 0.0 ? vec4(min(col.rgb / col.a, 1.0), col.a) : vec4(0.0);
}
