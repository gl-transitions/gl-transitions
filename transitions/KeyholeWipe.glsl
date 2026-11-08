// Author: gre
// License: MIT
// Description: A keyhole grows steadily from the center until the incoming image fills the frame, its bevelled rim and inner shadow making it read as a hole cut in a plate
// Tags: shape, wipe, keyhole, iris, reveal

// @param Center of the keyhole
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 1) Strength of the bevelled rim around the keyhole and the shadow inside it (0 for a clean cut)
uniform float rim; // = 0.6
// @range(0, 0.05) Softness of the keyhole's edge
uniform float smoothness; // = 0.002

// The keyhole, in its own units (0.85 tall, from y = -0.4 to 0.45): a round head on top of a slot
// that widens downward.
#define HEAD vec2(0.0, 0.2)
#define HEAD_R 0.25
#define SLOT_Y -0.17
const float SLOT_HE = 0.23;
const float SLOT_TOP = 0.085;
const float SLOT_BOTTOM = 0.165;
const float SLOT_ROUND = 0.025;
// height of the point the keyhole grows around, in its head
const float GROW_Y = 0.1;
// widths of the bevel and of the rim's shadows, in keyhole units
const float BEVEL = 0.028;
const float SHADE = 0.05;

float dot2(vec2 v) { return dot(v, v); }

// Signed distance to the slot, a trapezoid with rounded corners
float sdSlot(vec2 p) {
  p.y -= SLOT_Y;
  float r1 = SLOT_BOTTOM - SLOT_ROUND;
  float r2 = SLOT_TOP - SLOT_ROUND;
  float he = SLOT_HE - SLOT_ROUND;
  vec2 k1 = vec2(r2, he);
  vec2 k2 = vec2(r2 - r1, 2.0 * he);
  p.x = abs(p.x);
  vec2 ca = vec2(p.x - min(p.x, p.y < 0.0 ? r1 : r2), abs(p.y) - he);
  vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot2(k2), 0.0, 1.0);
  float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
  return s * sqrt(min(dot2(ca), dot2(cb))) - SLOT_ROUND;
}

float sdKeyhole(vec2 p) {
  return min(length(p - HEAD) - HEAD_R, sdSlot(p));
}

// Scale at which the keyhole's head, a disk, reaches the point p (seen from the growth point):
// the root of |p - s h| = s HEAD_R, h being the head's center
float reach(vec2 p) {
  vec2 h = HEAD - vec2(0.0, GROW_Y);
  float k = HEAD_R * HEAD_R - dot2(h);
  float b = dot(p, h);
  return (sqrt(b * b + k * dot2(p)) - b) / k;
}

vec4 transition (vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec2 asp = vec2(ratio, 1.0);
  vec2 c = center * asp;
  float sm = max(smoothness, 0.0005);

  // The keyhole grows around a point of its head, at the center. It covers the frame (grown by a
  // margin, so the soft edge is past it) once its head, a disk, reaches the frame's corners.
  vec2 o = c;
  vec2 lo = -o - 2.5 * sm;
  vec2 hi = asp - o + 2.5 * sm;
  float full = max(max(reach(lo), reach(hi)), max(reach(vec2(lo.x, hi.y)), reach(vec2(hi.x, lo.y))));

  // The keyhole grows linearly until it fills the frame
  float p = progress;
  float s = full * p;
  if (s <= 0.0) return a;

  vec2 q = (uv * asp - o) / s + vec2(0.0, GROW_Y);
  float d = sdKeyhole(q);
  // the soft edge is just inside the outline, so a tiny keyhole shows nothing
  float hole = 1.0 - smoothstep(-sm, sm, d * s + sm);

  float fade = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.7, 1.0, p));
  float rimA = rim * fade;
  if (rimA > 0.0) {
    // Plate around the hole: a bevel lit from above going down into the hole, and a soft shadow
    // on its rim
    vec2 e = vec2(0.002, 0.0);
    vec2 n = vec2(sdKeyhole(q + e) - sdKeyhole(q - e), sdKeyhole(q + e.yx) - sdKeyhole(q - e.yx));
    float lit = -dot(n / max(length(n), 1e-6), vec2(-0.35, 0.94));
    float bevel = 1.0 - smoothstep(0.0, BEVEL, d);
    float shade = exp(-max(d, 0.0) / SHADE);
    a.rgb *= 1.0 - rimA * (0.35 * shade + bevel * 0.4 * max(-lit, 0.0));
    a.rgb += rimA * bevel * bevel * 0.3 * max(lit, 0.0) * a.a;

    // Inside the hole: the plate's thickness shades the incoming image under the top of the rim,
    // with a softer vignette all around the edge
    float wall = smoothstep(-0.03, 0.03, sdKeyhole(q + vec2(0.0, 0.05)));
    float vign = exp(min(d, 0.0) / SHADE);
    b.rgb *= 1.0 - rimA * (0.5 * wall + 0.3 * vign);
  }

  return mix(a, b, hole);
}
