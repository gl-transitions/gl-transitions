// Author: gre
// License: MIT
// Description: The outgoing image breaks into hundreds of small squares that a tornado carries away along a spiral around the center, from the eye outward, uncovering the incoming image
// Tags: tiles, spiral, rotation, shatter

// @range(4, 40, 1) Number of rows of squares
uniform int grid; // = 24
// Center of the tornado
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(-4, 4) Turns each square makes around the center as it flies away (negative turns clockwise)
uniform float spin; // = 1.0
// @range(0, 1) How randomly the squares leave: 0 from the center outward, 1 in any order
uniform float randomness; // = 0.2

// the squares leave in GROUPS waves, each one flying for DURATION of the transition
const int GROUPS = 24;
const float DURATION = 0.25;
// half width of the antialiased edge of the squares, in frame heights
const float AA = 0.0015;
const float TAU = 6.2831853;

float hash(vec2 n) {
  return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
}

// the wave a square (by its cell index) leaves with
int groupOf(vec2 n, float h, vec2 c, float maxR) {
  // only the very corners leave last
  float r = min(length((n + 0.5) * h - c) / (0.85 * maxR), 1.0);
  float key = clamp(mix(r * sqrt(r), hash(n), clamp(randomness, 0.0, 1.0)), 0.0, 0.9999);
  return int(floor(key * float(GROUPS)));
}

// local time of a wave's flight, 0 before it leaves, 1 once it has vanished
float flight(int g) {
  float delay = float(g) / float(GROUPS) * (1.0 - DURATION);
  return clamp((progress - delay) / DURATION, 0.0, 1.0);
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  // measured in square pixels, so the squares stay square
  vec2 aspect = vec2(ratio, 1.0);
  vec2 p = uv * aspect;
  vec2 c = center * aspect;
  float maxR = max(max(length(c), length(c - vec2(ratio, 0.0))), max(length(c - vec2(0.0, 1.0)), length(c - aspect)));
  float h = 1.0 / float(grid < 1 ? 1 : grid);
  // how far a square is pushed away from the center by the end of its flight
  float reach = 0.7 * maxR;

  // the incoming image, under the squares that have not left yet
  vec2 n0 = floor(p / h);
  vec4 col = flight(groupOf(n0, h, c, maxR)) <= 0.0 ? premultiplied(getFromColor(uv)) : premultiplied(getToColor(uv));

  // the flying squares, painted from the last wave to leave (lowest) to the first (highest)
  for (int k = 0; k < GROUPS; k++) {
    int g = GROUPS - 1 - k;
    float s = flight(g);
    if (s <= 0.0 || s >= 1.0) continue;
    float e = s * s;
    // like in a tornado, the squares near the eye (the first to leave) spin much faster than
    // the outer ones; all of them orbit before they are flung out
    float angle = spin * TAU * e * 2.0 / (1.0 + 6.0 * float(g) / float(GROUPS));
    float push = reach * e * s;
    // the squares lift toward the viewer, then shrink away
    float size = (1.0 + 0.35 * sin(3.1415927 * s)) * (1.0 - s * s * s);
    float ca = cos(angle);
    float sa = sin(angle);
    mat2 rot = mat2(ca, sa, -sa, ca);
    // undo the wave's spiral to guess which square lands here, then test its neighbors exactly
    vec2 u = (p - c) * rot;
    float ru = length(u);
    vec2 guess = c + (ru > 0.0 ? u / ru : vec2(0.0)) * max(ru - push, 0.0);
    vec2 ng = floor(guess / h);
    for (int j = -1; j <= 1; j++) {
      for (int i = -1; i <= 1; i++) {
        vec2 n = ng + vec2(float(i), float(j));
        if (groupOf(n, h, c, maxR) != g) continue;
        vec2 home = (n + 0.5) * h;
        vec2 rel = home - c;
        float rr = length(rel);
        vec2 dir = rr > 0.0 ? rel / rr : vec2(0.0);
        vec2 pos = c + rot * (dir * (rr + push));
        // each square also tumbles on itself
        float tumble = angle + (hash(n + 17.0) - 0.5) * 3.0 * e * sign(spin);
        float ct = cos(tumble);
        float st = sin(tumble);
        vec2 d = ((p - pos) * mat2(ct, st, -st, ct)) / max(size, 1e-4);
        float edge = 0.5 * h - max(abs(d.x), abs(d.y));
        float cov = clamp(edge * size / (2.0 * AA) + 0.5, 0.0, 1.0);
        vec2 src = home + d;
        if (cov <= 0.0 || src.x < 0.0 || src.y < 0.0 || src.x > ratio || src.y > 1.0) continue;
        vec4 piece = premultiplied(getFromColor(src / aspect)) * cov;
        col = piece + col * (1.0 - piece.a);
      }
    }
  }
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
