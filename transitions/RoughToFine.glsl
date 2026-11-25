// Author: gre
// License: MIT
// Description: Huge flat tilted squares in the incoming image's colors slap over the frame, then smaller ones tilted another way, and smaller still, layer on layer, until the heap of squares turns out to be the incoming image
// Tags: squares, mosaic, flat, layers, abstract, collage
// Preview: 0.45

// @range(0.6, 2.5) Largest squares over the height of the frame
uniform float big; // = 1.0
// @range(0, 1) How far the squares overshoot their size
uniform float kick; // = 0.5

vec3 hash3(vec3 p) {
  p = fract(p * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yxz + 33.33);
  return fract((p.xxy + p.yxx) * p.zyx);
}

// the incoming image around the middle of a square
vec4 flatColor(vec3 square) {
  vec4 s = vec4(0.0);
  for (int i = 0; i < 8; i++) {
    float f = float(i);
    vec2 o = 0.35 * square.z * sqrt((f + 0.5) / 8.0) * vec2(cos(f * 2.4), sin(f * 2.4));
    vec4 c = getToColor(clamp((square.xy + o) / vec2(ratio, 1.0) + 0.5, 0.0, 1.0));
    s += vec4(c.rgb * c.a, c.a);
  }
  return vec4(s.rgb / max(s.a, 1e-4), s.a / 8.0);
}

vec4 transition(vec2 uv) {
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  // center and size of the topmost square and of the one under its edge; a size of 0 is the outgoing image
  vec3 top = vec3(0.0), under = vec3(0.0);
  float edge = 1.0;
  // from the top layer down, to stop as soon as the pixel is covered
  for (int l = 0; l < 7; l++) {
    float L = 6.0 - float(l);
    float age = progress - 0.01 - 0.105 * L;
    if (age <= 0.0) continue;
    float n = big * pow(1.8, L);
    float turn = 0.42 + 0.9 * L;
    vec2 r = vec2(cos(turn), sin(turn));
    vec2 g = vec2(r.x * p.x - r.y * p.y, r.y * p.x + r.x * p.y) * n + L * 7.31;
    vec2 c = floor(g);
    float z1 = -1.0, z2 = -1.0, cov = 0.0;
    vec2 e1 = vec2(0.0), e2 = vec2(0.0);
    for (int i = 0; i < 9; i++) {
      vec2 o = c + vec2(mod(float(i), 3.0) - 1.0, floor(float(i) / 3.0) - 1.0);
      vec3 h = hash3(vec3(o, L + 3.0));
      float t = clamp((age - 0.13 * h.z) / 0.13, 0.0, 1.0);
      float b = t - 1.0;
      float size = 0.86 * (1.0 + b * b * ((kick * 2.0 + 1.0) * b + kick * 2.0));
      vec2 e = o + 0.5 + 0.7 * (h.xy - 0.5);
      vec2 v = abs(g - e);
      float cv = clamp(0.5 - (max(v.x, v.y) - size) / n * 500.0, 0.0, 1.0) * step(1e-4, t);
      if (cv > 0.0 && h.z > z1) {
        z2 = z1;
        e2 = e1;
        z1 = h.z;
        e1 = e;
        cov = cv;
      } else if (cv > 0.0 && h.z > z2) {
        z2 = h.z;
        e2 = e;
      }
    }
    if (z1 >= 0.0) {
      e1 = (e1 - L * 7.31) / n;
      e2 = (e2 - L * 7.31) / n;
      vec3 s1 = vec3(r.x * e1.x + r.y * e1.y, r.x * e1.y - r.y * e1.x, 1.0 / n);
      vec3 s2 = vec3(r.x * e2.x + r.y * e2.y, r.x * e2.y - r.y * e2.x, 1.0 / n);
      if (top.z > 0.0) {
        under = s1;
        break;
      }
      top = s1;
      edge = cov;
      if (z2 >= 0.0) under = s2;
      if (z2 >= 0.0 || cov >= 1.0) break;
    }
  }
  vec4 c1 = top.z > 0.0 ? flatColor(top) : getFromColor(uv);
  vec4 c0 = c1;
  if (edge < 1.0) c0 = under.z > 0.0 ? flatColor(under) : getFromColor(uv);
  return mix(mix(c0, c1, edge), getToColor(uv), smoothstep(0.82, 1.0, progress));
}
