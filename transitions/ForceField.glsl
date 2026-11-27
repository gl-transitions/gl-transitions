// Author: gre
// License: MIT
// Description: The outgoing image sits behind a hexagonal energy shield that takes four shots in a row: each hit flares, a wave of lit hexagons ripples out from it and bends the picture like a lens, and every hexagon the wave passes turns into the incoming image from its center
// Tags: hexagon, shield, energy, impact, ripple, game

// @range(3, 20) Number of hexagons across the shorter side
uniform float size; // = 9.0
// @range(0, 2) Strength of the shield light
uniform float glow; // = 1.0
// @color Color of the shield light (its alpha is its strength)
uniform vec4 shieldColor; // = vec4(0.35, 0.85, 1.0, 1.0)

const vec2 HIT0 = vec2(0.30, 0.64);
const vec2 HIT1 = vec2(0.74, 0.34);
const vec2 HIT2 = vec2(0.22, 0.22);
const vec2 HIT3 = vec2(0.78, 0.80);
const vec3 SHOT = vec3(0.12, 0.24, 0.36);
// the last hexagon starts turning at END, so it is done at END + GROW
const float END = 0.9;
const float GROW = 0.1;

float hexDist(vec2 p) {
  p = abs(p);
  return max(p.x, dot(p, vec2(0.5, 0.8660254)));
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec2 toAspect(vec2 v) {
  return (v - 0.5) * vec2(ratio, 1.0);
}

float arrival(vec2 q, vec4 shots) {
  return min(
    min(shots.x + length(q - toAspect(HIT0)), shots.y + length(q - toAspect(HIT1))),
    min(shots.z + length(q - toAspect(HIT2)), shots.w + length(q - toAspect(HIT3)))
  );
}

// fires each shot before the earlier waves reach its spot, so all four hits show in narrow frames too
vec4 shotTimes() {
  float s1 = min(SHOT.x, 0.6 * arrival(toAspect(HIT1), vec4(0.0, 9.0, 9.0, 9.0)));
  float s2 = min(SHOT.y, 0.6 * arrival(toAspect(HIT2), vec4(0.0, s1, 9.0, 9.0)));
  float s3 = min(SHOT.z, 0.6 * arrival(toAspect(HIT3), vec4(0.0, s1, s2, 9.0)));
  return vec4(0.0, s1, s2, s3);
}

// smoothstep keeps the corners from trailing: the waves ease in, then speed up to sweep the last border cells
float timing(float t, float last) {
  return END * smoothstep(0.0, 1.0, t / last);
}

float flare(vec2 q, vec2 hit, float t0) {
  float dt = max(progress - t0, 0.0);
  vec2 d = q - toAspect(hit);
  return dt / (dt + 0.01) * exp(-dt / 0.07 - dot(d, d) / 0.006);
}

vec4 transition(vec2 uv) {
  vec2 ar = vec2(ratio, 1.0);
  vec2 toCells = ar * size / min(ratio, 1.0);
  vec2 p = (uv - 0.5) * toCells;
  const vec2 grid = vec2(1.0, 1.7320508);
  vec2 a = (floor(p / grid) + 0.5) * grid;
  vec2 b = (floor((p - 0.5 * grid) / grid) + 1.0) * grid;
  vec2 center = dot(p - a, p - a) < dot(p - b, p - b) ? a : b;
  vec2 local = p - center;
  vec2 q = (uv - 0.5) * ar;

  vec4 shots = shotTimes();
  // the corners and the top and bottom middles are the frame's latest points, so the waves end near END at any ratio
  float h = 0.5 * ratio;
  float last = max(
    max(max(arrival(vec2(-h, -0.5), shots), arrival(vec2(h, -0.5), shots)), max(arrival(vec2(-h, 0.5), shots), arrival(vec2(h, 0.5), shots))),
    max(arrival(vec2(0.0, -0.5), shots), arrival(vec2(0.0, 0.5), shots))
  );

  float T = timing(arrival(center / toCells * ar, shots), last);
  float grow = smoothstep(T, T + GROW, progress);
  float hd = hexDist(local);
  float r = 0.64 * grow;
  float s = 1.0 - smoothstep(r - 0.05, r, hd);

  float env = min(1.0, 8.0 * progress * (1.0 - progress));
  float front = (progress - T) / 0.06;
  float ring = env * exp(-front * front);
  float lit = 6.75 * grow * (1.0 - grow) * (1.0 - grow);
  float edge = smoothstep(0.25, 0.5, hd);
  float rim = smoothstep(r - 0.14, r, hd) * (1.0 - smoothstep(r, r + 0.02, hd)) * lit;

  vec2 bend = local / toCells * 0.06 * (ring + 0.5 * lit);
  vec4 col = mix(getFromColor(mirror(uv - bend)), getToColor(mirror(uv - bend)), s);

  float impact = flare(q, HIT0, 0.0) + flare(q, HIT1, timing(shots.y, last))
               + flare(q, HIT2, timing(shots.z, last)) + flare(q, HIT3, timing(shots.w, last));
  float g = glow * shieldColor.a * (ring * (0.25 + 0.75 * edge) + 0.3 * lit * edge + 0.7 * rim + env * impact);
  vec3 light = shieldColor.rgb * g;
  // the shield lights the picture behind it rather than painting over it
  col.rgb = col.rgb * (1.0 + 1.4 * light) + col.a * light * (0.08 + 0.12 * light);
  return vec4(min(col.rgb, vec3(col.a)), col.a);
}
