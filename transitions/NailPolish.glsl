// Author: gre
// License: MIT
// Description: The incoming picture is lacquered over the outgoing one in three glossy strokes, middle first then left and right, each a wet coat with a rounded brush end pushing a bead of lacquer, a window highlight, a thick refracting edge and fine brush streaks that level out as it dries
// Tags: paint, gloss, brush, wipe, liquid

// @range(0, 1) Shine of the wet lacquer
uniform float gloss; // = 0.7
// @range(0, 1) How streaky the brush leaves the coat before it levels
uniform float streaks; // = 0.6

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// x: coverage, y: across the stroke (-1..1), z: age behind the brush, w: distance to the edge
vec4 stroke(vec2 q, float cx, float hw, float t0, float seed) {
  float s = clamp((progress - t0) / 0.5, 0.0, 1.0);
  s = s * s * (3.0 - 2.0 * s);
  float dx = q.x - cx;
  float w = hw * (1.0 + 0.06 * (vnoise(vec2(q.y * 5.0, seed)) - 0.5));
  float u = dx / w;
  float head = mix(1.02, -0.3, s) + 0.16 * u * u;
  float dy = q.y - head;
  float e = min(w - abs(dx), dy);
  float cov = smoothstep(-0.002, 0.002, e);
  return vec4(cov, u, max(dy, 0.0) / 1.55 + max(progress - t0 - 0.5, 0.0), e);
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float hw = 0.24 * ratio;
  vec4 s0 = stroke(q, 0.5 * ratio, hw, 0.0, 1.0);
  vec4 s1 = stroke(q, 0.2 * ratio, hw, 0.22, 5.0);
  vec4 s2 = stroke(q, 0.8 * ratio, hw, 0.44, 9.0);
  vec4 s = s0;
  if (s1.x > 0.5) s = s1;
  if (s2.x > 0.5) s = s2;
  float cov = max(max(s0.x, s1.x), s2.x);
  float fin = 1.0 - smoothstep(0.8, 1.0, progress);
  float wet = exp(-3.5 * s.z) * fin;
  float lines = vnoise(vec2(s.y * 38.0, q.y * 1.5)) - 0.5;
  float rim = exp(-max(s.w, 0.0) / 0.02) * cov * fin;
  float bead = exp(-max(s.z * 1.55, 0.0) / 0.03) * cov * fin;
  vec2 off = vec2(lines * 0.012 * streaks * wet - 0.02 * bead * s.y, 0.03 * bead - 0.012 * rim);
  vec4 a = getFromColor(uv);
  vec2 ub = 1.0 - abs(1.0 - abs(uv + off));
  vec4 b = getToColor(ub);

  vec3 c = b.rgb;
  float l = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(c, clamp(l + (c - l) * 1.35, 0.0, 1.0), wet);
  c *= 1.0 + lines * 0.3 * streaks * wet - 0.35 * rim - 0.25 * bead;
  float bx = (s.y + 0.45) / 0.22;
  float band = exp(-bx * bx) * (0.75 + 0.25 * vnoise(vec2(s.y * 9.0, q.y * 3.0)));
  float spec = smoothstep(0.45, 0.95, band) * 0.65 + 0.2 * band;
  float lip = exp(-abs(s.w - 0.006) / 0.003);
  float shine = gloss * (wet * spec + 0.6 * rim * lip + 0.5 * bead * exp(-abs(s.z * 1.55 - 0.012) / 0.006));
  c = 1.0 - (1.0 - c) * (1.0 - clamp(shine, 0.0, 1.0));
  return vec4(mix(a.rgb, clamp(c, 0.0, 1.0), cov), mix(a.a, b.a, cov));
}
