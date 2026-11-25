// Author: gre
// License: MIT
// Description: The view moves in until the outgoing picture is seen to be woven of upright threads; they dive one by one, in a satin order, under crosswise threads dyed as the incoming picture, and the view moves back out
// Tags: fabric, weave, threads, textile, 3d
// Preview: 0.5

// @range(40, 160) Number of threads across the frame's diagonal
uniform float threads; // = 120.0
// @range(1, 4) How close the view moves in
uniform float closeUp; // = 2.0
// @range(0, 1) Sheen of the threads
uniform float sheen; // = 0.5

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

// 1 where the upright thread lies on top, -1 where it has gone under
float over(vec2 c, float flip) {
  float satin = mod(c.x * 2.0 + c.y, 5.0) / 4.0;
  float when = 0.6 * satin + 0.4 * noise(c / 9.0 + 50.0);
  return 1.0 - 2.0 * smoothstep(when - 0.09, when + 0.09, flip);
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 cloth(vec2 v, vec2 grid, float flip, float near) {
  vec2 g = (v - 0.5) * grid;
  vec2 c = floor(g);
  vec2 l = g - c - 0.5;
  vec2 s = vec2(l.x < 0.0 ? -1.0 : 1.0, l.y < 0.0 ? -1.0 : 1.0);
  float o = over(c, flip);
  float oy = over(c + vec2(0.0, s.y), flip);
  float ox = over(c + vec2(s.x, 0.0), flip);
  float ky = smoothstep(0.1, 0.9, abs(l.y));
  float kx = smoothstep(0.1, 0.9, abs(l.x));
  float ra = sqrt(max(1.0 - l.x * l.x * 4.2, 0.0));
  float rb = sqrt(max(1.0 - l.y * l.y * 4.2, 0.0));
  float za = mix(o, oy, ky) + ra * 0.9;
  float zb = -mix(o, ox, kx) + rb * 0.9;
  float top = smoothstep(-0.15, 0.15, za - zb);
  vec3 na = normalize(vec3(l.x * 2.0, -(oy - o) * s.y * 0.5, 0.35 + ra));
  vec3 nb = normalize(vec3((ox - o) * s.x * 0.5, l.y * 2.0, 0.35 + rb));
  vec3 n = normalize(mix(nb, na, top));
  // a thread is dyed along its length, with one color across
  vec2 mid = (c + 0.5) / grid + 0.5;
  vec4 a = pm(getFromColor(vec2(mix(v.x, mid.x, 0.85 * near), v.y)));
  vec4 b = pm(getToColor(vec2(v.x, mix(v.y, mid.y, 0.85 * near))));
  float twist = mix(sin((l.x + c.x + l.y * 1.6) * 12.566), sin((l.y + c.y + l.x * 1.6) * 12.566), top);
  vec4 col = mix(b, a, top);
  vec3 lamp = normalize(vec3(-0.4, 0.6, 0.8));
  float lit = 0.55 + 0.6 * max(dot(n, lamp), 0.0);
  lit *= clamp(max(za, zb) * 0.5 + 0.6, 0.5, 1.05);
  lit *= 1.0 - 0.28 * (1.0 - smoothstep(0.0, 0.6, abs(za - zb)));
  float spec = pow(max(dot(reflect(vec3(0.0, 0.0, -1.0), n), lamp), 0.0), 8.0);
  vec3 shaded = col.rgb * lit * (1.0 + 0.07 * twist) * 1.12 + sheen * 0.35 * spec * (0.3 * col.a + col.rgb);
  // without depth the crossings alone give the plain pictures at both ends
  vec4 plain = mix(b, a, 0.5 + 0.5 * o);
  float tex = smoothstep(0.25, 1.0, near);
  return vec4(mix(plain.rgb, shaded, tex), mix(plain.a, col.a, tex));
}

vec4 transition(vec2 uv) {
  float p = progress;
  float near = smoothstep(0.0, 0.34, p) * (1.0 - smoothstep(0.66, 1.0, p));
  float e = clamp((p - 0.08) / 0.84, 0.0, 1.0);
  float flip = mix(-0.1, 1.1, mix(e, e * e * (3.0 - 2.0 * e), 0.5));
  vec2 asp = vec2(ratio, 1.0);
  vec2 grid = max(floor(threads * asp / length(asp)), 2.0);
  float zoom = mix(1.0, 1.0 / max(closeUp, 1.0), near);
  vec4 sum = vec4(0.0);
  // four samples, for the fine ribs
  for (int i = 0; i < 4; i++) {
    vec2 j = vec2(mod(float(i), 2.0), floor(float(i) * 0.5 + 0.01)) - 0.5;
    j = vec2(j.x * 0.8 - j.y * 0.4, j.x * 0.4 + j.y * 0.8) * 0.0016 * near / asp;
    sum += 0.25 * cloth(0.5 + (uv - 0.5 + j) * zoom, grid, flip, near);
  }
  return sum.a > 0.0 ? vec4(min(sum.rgb / sum.a, 1.0), sum.a) : vec4(0.0);
}
