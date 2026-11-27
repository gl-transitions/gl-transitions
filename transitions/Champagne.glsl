// Author: gre
// License: MIT
// Description: A frothy jet of champagne shoots up from the bottom middle of the frame, throwing droplets ahead of it; wherever the spray lands it splats into cream foam, the splats spread outward and merge, and as the jet flies off the foam fizzes away onto the incoming image
// Tags: celebration, liquid, foam, spray, festival, reveal

// @range(4.0, 14.0) Number of splats across the frame height
uniform float splashes; // = 7.0
// @range(0.1, 0.5) How long each splat fizzes, as a fraction of the transition
uniform float fizz; // = 0.35
// @color Color of the foam
uniform vec4 foam; // = vec4(1.0, 0.97, 0.88, 1.0)
// @color Color of the flying droplets
uniform vec4 spray; // = vec4(1.0, 0.94, 0.78, 1.0)

vec2 hash2(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x), mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + 1.0).x, f.x), f.y);
}

float streaks(float ang, float rad, float cells, float seed, float flight) {
  float ac = ang * cells / 3.14159;
  float ci = floor(ac);
  vec2 h = hash2(vec2(ci, seed));
  float off = (ac - ci - 0.2 - 0.6 * h.x) * 3.14159 / cells * rad;
  float len = 0.09;
  float u = rad - flight * (0.8 + 0.4 * h.y) - hash2(vec2(seed, ci)).x * len;
  vec2 k = hash2(vec2(ci, floor(u / len) + seed * 13.0));
  float along = fract(u / len) * len;
  float l = 0.03 + 0.05 * k.x;
  float w = 0.002 + 0.003 * k.y;
  float t = clamp(along / l, 0.0, 1.0);
  float tail = t * exp(-off * off / (w * w * t + 1e-6));
  vec2 hd = vec2(along - l, off);
  float head = (1.0 - smoothstep(1.0, 1.6, length(hd) / w));
  return max(tail, head) * step(along, l + 2.0 * w) * step(k.y, 0.75);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec2 P = uv * vec2(ratio, 1.0);
  vec2 S = vec2(0.5 * ratio, -0.05);
  vec2 p = P * splashes;
  vec2 src = S * splashes;
  float near = 0.3 * splashes;
  float far = length(vec2(0.5 * ratio, 1.05)) * splashes;
  float span = 1.0 - fizz;
  float n = vnoise(p * 1.7) * 0.55 + vnoise(p * 4.1 + 3.7) * 0.3 + vnoise(p * 9.3 + 1.3) * 0.15;
  vec2 cell = floor(p);
  float field = 0.0;
  float thick = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 c = cell + vec2(float(i), float(j));
      vec2 h = hash2(c);
      vec2 o = c + 0.3 + 0.4 * h;
      float t0 = span * clamp(0.85 * (length(o - src) - near) / (far - near) + 0.15 * h.y, 0.0, 1.0);
      float age = clamp((progress - t0) / fizz, 0.0, 1.0);
      float grow = 1.0 - (1.0 - age) * (1.0 - age) * (1.0 - age);
      vec2 d = p - o;
      float ang = atan(d.y, d.x + 1e-4);
      float lobes = 1.0 + 0.07 * sin(ang * 3.0 + h.x * 6.28) + 0.05 * sin(ang * 7.0 - h.y * 6.28);
      float r = length(d) / lobes;
      float rad = 1.05 * grow;
      float s = (1.0 - smoothstep(rad - 0.12, rad, r + 0.35 * n * (1.0 - age))) * step(0.001, age);
      field = max(field, s);
      thick = max(thick, s * (1.0 - age) * (1.0 + 0.7 * age));
    }
  }

  float sheet = smoothstep(n - 0.18, n + 0.12, thick * 1.4) * smoothstep(0.0, 0.25, field) * smoothstep(0.0, 0.06, thick);
  float body = smoothstep(n - 0.1, n + 0.5, thick * 1.4);
  vec2 q = P * 60.0;
  vec2 bh = hash2(floor(q) + 7.0);
  vec2 bd = fract(q) - 0.3 - 0.4 * bh;
  float br = 0.1 + 0.15 * bh.x;
  float bub = length(bd) / br;
  float held = smoothstep(bh.y * 0.9, bh.y * 0.9 + 0.1, thick) * sheet;
  float ring = (1.0 - smoothstep(0.8, 1.0, bub)) * smoothstep(0.4, 0.8, bub) * held;
  float shine = (1.0 - smoothstep(0.1, 0.4, length(bd / br + vec2(0.3, -0.3)))) * held;

  vec2 d = P - S;
  float radius = length(d);
  float ang = atan(d.x, d.y);
  float front = mix(0.3, length(vec2(0.5 * ratio, 1.05)), clamp(progress / span / 0.85, 0.0, 1.0));
  float tp = progress / span;
  float env = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.6, 1.0, tp));
  float lead = smoothstep(front - 0.2, front, radius) * (1.0 - smoothstep(front, front + 0.25, radius));
  float flight = progress * 4.0;
  float drops = streaks(ang, radius, 48.0, 1.0, flight) + streaks(ang, radius, 77.0, 2.0, flight * 1.2);
  float top = front * smoothstep(0.0, 0.1, progress);
  float base = 1.6 * smoothstep(0.46, 1.0, tp) - 0.1;
  float dx = d.x - 0.04 * d.y * sin(d.y * 5.0 - progress * 18.0);
  float wd = 0.018 + 0.24 * d.y;
  float froth = vnoise(vec2(dx / wd * 2.5, d.y * 9.0 - flight * 6.0)) * 0.6 + vnoise(vec2(dx * 70.0, d.y * 22.0 - flight * 14.0)) * 0.4;
  float jet = (1.0 - smoothstep(0.75, 0.95, abs(dx) / wd + 0.8 * (froth - 0.5) * (0.3 + d.y)));
  jet *= (1.0 - smoothstep(top - 0.35, top - 0.05, d.y + 0.3 * froth)) * smoothstep(base - 0.1, base + 0.1, d.y - 0.1 * froth);
  float cone = (1.0 - smoothstep(1.0, 1.5, abs(dx) / wd)) * (1.0 - smoothstep(top - 0.2, top + 0.1, d.y)) * smoothstep(base - 0.1, base + 0.2, d.y);
  drops *= env * max(lead * (1.0 - 0.6 * sheet), cone);
  float gloss = 0.8 + 0.14 * vnoise(vec2(dx / wd * 9.0, d.y * 1.5 - flight * 4.0)) + 0.06 * (1.0 - smoothstep(0.0, 0.35, abs(dx / wd + 0.3)));

  vec4 col = mix(a, b, smoothstep(0.4, 1.0, field));
  vec4 cream = foam * vec4(vec3(0.86 + 0.08 * body - 0.1 * ring + 0.06 * shine), 1.0);
  col = mix(col, cream, sheet);
  col = mix(col, spray, clamp(drops, 0.0, 1.0) * 0.9);
  col = mix(col, spray * vec4(vec3(gloss), 1.0), jet * 0.92);
  return col;
}
