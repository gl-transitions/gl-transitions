// Author: gre
// License: MIT
// Description: The incoming image is tossed in as a small card that flies along an arc over the outgoing image and lands full frame, lit by a strobe: every flash freezes a crisp copy of the card where it was, so a trail of pictures records its flight
// Tags: strobe, multiple-exposure, card, toss

// @range(2, 10, 1) Number of strobe flashes, each leaving a copy of the card
uniform int flashes; // = 7
// @range(0, 1) Strength of the strobe flash on each new copy
uniform float pop; // = 0.5
// @range(0, 1) How much the outgoing image darkens behind the copies
uniform float dim; // = 0.35
// @color Paper border around each card
uniform vec4 border; // = vec4(0.96, 0.95, 0.92, 1.0)

const int MAX_FLASHES = 10;
const float PI = 3.14159265;

float growth(float t) {
  return smoothstep(0.5, 1.0, t);
}

// card pose at time t: center (frame units, y up), scale, angle
vec4 pose(float t, vec2 box) {
  float u = 1.0 - pow(1.0 - clamp(t / 0.8, 0.0, 1.0), 1.6);
  float g = growth(t);
  float a = PI + 0.35 - (PI + 0.2) * u;
  // the start radius keeps the card and its shadow just outside the frame at t = 0
  vec2 r = vec2(mix((0.5 * box.x + 0.15 * length(box) + 0.07) / 0.93, 0.31 * max(box.x, 1.0), sqrt(u)), 0.3);
  vec2 c = r * vec2(cos(a), sin(a)) + vec2(0.0, 0.04);
  return vec4(c * (1.0 - g), mix(0.3, 1.0, g * g), 0.9 * (u - 0.5) * (1.0 - g) * (1.0 - g) - 0.6 * (1.0 - u));
}

float edgeDist(vec2 l, vec4 P, vec2 box) {
  vec2 e = abs(l) - 0.5 * box * P.z;
  return max(e.x, e.y);
}

// shadow: strength of its drop shadow, which a new copy grows so it does not double the live card's
vec4 card(vec4 acc, vec2 q, vec2 box, float t, float age, float shadow, float flash, float px) {
  vec4 P = pose(t, box);
  float k = 1.0 - growth(t);
  float c = cos(P.w), s = sin(P.w);
  mat2 rot = mat2(c, -s, s, c);
  vec2 l = rot * (q - P.xy);
  float ds = edgeDist(l - rot * vec2(0.018, -0.026) * k, P, box);
  acc.rgb *= 1.0 - 0.5 * shadow * sqrt(k) * (1.0 - smoothstep(-0.02, 0.03, ds));
  float d = edgeDist(l, P, box);
  // no AA once full frame, so the frame border lands exact
  float aa = px * clamp(k * 12.0, 1e-4, 1.0);
  float cov = clamp(0.5 - d / aa, 0.0, 1.0);
  vec4 col = getToColor(clamp(l / (box * P.z) + 0.5, 0.0, 1.0));
  col = mix(col, border, clamp(0.5 + (d + 0.016 * sqrt(k)) / aa, 0.0, 1.0));
  col.rgb *= 1.0 - 0.3 * clamp(age, 0.0, 1.0) * k;
  col.rgb = mix(col.rgb, vec3(1.0), flash * k);
  return mix(acc, col, cov);
}

vec4 transition(vec2 uv) {
  vec2 box = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * box;
  float px = 0.002;
  float p = progress;
  vec4 acc = getFromColor(uv);
  acc.rgb *= 1.0 - clamp(dim, 0.0, 1.0) * smoothstep(0.0, 0.5, p);
  float n = clamp(float(flashes), 2.0, float(MAX_FLASHES));
  for (int i = 1; i <= MAX_FLASHES; i++) {
    float t = float(i) / (n + 1.0);
    if (float(i) > n || t > p) break;
    float age = (p - t) * (n + 1.0);
    acc = card(acc, q, box, t, age, smoothstep(0.0, 0.6, age), 0.0, px);
  }
  float last = min(floor(p * (n + 1.0)), n);
  float flash = clamp(pop, 0.0, 1.0) * step(1.0, last) * exp(-(p * (n + 1.0) - last) * 9.0);
  acc = card(acc, q, box, p, -1.0, 1.0, 0.6 * flash, px);
  acc.rgb += 0.15 * flash * (1.0 - growth(p));
  return acc;
}
