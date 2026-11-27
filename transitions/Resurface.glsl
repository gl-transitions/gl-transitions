// Author: gre
// License: MIT
// Description: Like an ice resurfacer doing laps of a rink, a band drives counter-clockwise along the border of the outgoing picture and spirals inward lap after lap behind a bright squeegee line, leaving the incoming picture under a glossy, slightly rippled film of fresh water that dries as the machine moves on
// Tags: spiral, ice, water, gloss, wipe

// @range(2, 8, 1) Number of laps the machine drives, from the border inward
uniform float laps; // = 4.0
// @range(0, 1) Gloss of the fresh water before it dries
uniform float gloss; // = 0.7

// position of q along the k-th lap, counter-clockwise, in laps
float lapPos(vec2 q, float k, float bw) {
  float inset = (k + 0.5) * bw;
  vec2 h = max(vec2(0.5 * ratio, 0.5) - inset, vec2(1e-3));
  float per = 4.0 * (h.x + h.y);
  float s;
  if (0.5 - abs(q.y) < 0.5 * ratio - abs(q.x)) {
    s = q.y < 0.0 ? clamp(q.x + h.x, 0.0, 2.0 * h.x) : 2.0 * h.x + 2.0 * h.y + clamp(h.x - q.x, 0.0, 2.0 * h.x);
  } else {
    s = q.x > 0.0 ? 2.0 * h.x + clamp(q.y + h.y, 0.0, 2.0 * h.y) : 4.0 * h.x + 2.0 * h.y + clamp(h.y - q.y, 0.0, 2.0 * h.y);
  }
  // each lap starts and ends at the middle of the bottom side
  return k + mod(s - h.x, per) / per;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float n = max(floor(laps + 0.5), 1.0);
  float bw = 0.5 * min(ratio, 1.0) / n;
  float edge = min(0.5 * ratio - abs(q.x), 0.5 - abs(q.y));
  float f = edge / bw;
  float k = min(floor(f), n - 1.0);
  float fr = f - k;
  float head = (n + 0.12) * mix(p, p * p * (3.0 - 2.0 * p), 0.5) - 0.06;
  float w = 0.012;
  float s0 = lapPos(q, k, bw);
  // blend with the neighboring lap across the boundary so lap edges stay smooth
  float kn = clamp(k + (fr < 0.5 ? -1.0 : 1.0), 0.0, n - 1.0);
  float s1 = lapPos(q, kn, bw);
  float px = 0.002 / bw;
  float bl = kn != k ? 0.5 - 0.5 * smoothstep(0.0, px, min(fr, 1.0 - fr)) : 0.0;
  float s = mix(s0, s1, bl);
  float flip = smoothstep(-w, w, head - s);
  float age = max(head - s, 0.0);
  float wet = gloss * exp(-age * 2.2) * flip * (1.0 - smoothstep(0.75, 1.0, p));

  vec4 a = getFromColor(uv);
  vec2 rip = 0.004 * wet * vec2(sin(140.0 * q.y + 30.0 * p), cos(120.0 * q.x));
  vec4 b = getToColor(1.0 - abs(1.0 - abs(uv + rip)));
  // fresh water lies glossy over the ice and mirrors the overhead lights
  float sheen = 0.5 + 0.5 * sin(5.0 * (q.x - 0.6 * q.y));
  vec3 wb = mix(b.rgb, vec3(0.9, 0.95, 1.0), wet * (0.15 + 0.3 * sheen));
  float sq = (head - s) / (2.5 * w);
  vec3 squeegee = vec3(1.0) * exp(-sq * sq) * 0.6 * (1.0 - smoothstep(0.9, 1.0, p));
  vec3 col = mix(a.rgb, wb, flip) + squeegee * flip;
  return vec4(min(col, 1.0), mix(a.a, b.a, flip));
}
