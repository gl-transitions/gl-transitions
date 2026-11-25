// Author: gre
// License: MIT
// Description: Neighboring areas of the outgoing image with the same color flow together into ever larger rounded shapes; one after another the areas change to the incoming image's colors, part from their old neighbors and join new ones, until the shapes sharpen into the incoming image
// Tags: color, shapes, cells, organic, abstract, morph
// Preview: 0.48

// @range(0.06, 0.25) Coarseness of the areas at the middle, in frame heights
uniform float size; // = 0.14
// @range(10, 80) How alike two colors must be to join
uniform float likeness; // = 45.0

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 hash2(vec2 p) {
  vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

// when a site changes sides
float turning(float h) {
  return (progress - 0.34 - 0.2 * h) / 0.12;
}

// the premultiplied color of the image at a site
vec4 site(vec2 id, vec4 toUv) {
  vec2 h = hash2(id);
  vec2 c = id + 0.5 * h;
  vec2 q = fold(vec2(dot(toUv.xy, c), dot(toUv.zw, c)) + 0.5);
  vec4 s = turning(h.x) > 0.5 ? getToColor(q) : getFromColor(q);
  return vec4(s.rgb * s.a, s.a);
}

// the square root of a site's weight
float near(vec2 g, vec2 id) {
  vec2 h = hash2(id);
  vec2 d = g - id - 0.5 * h;
  float k = max(1.0 - dot(d, d) / 2.0, 0.0);
  return sqrt(k * k * k * smoothstep(0.0, 1.0, abs(2.0 * turning(h.x) - 1.0)) + 1e-5);
}

vec3 nears(vec2 g, vec2 id) {
  return vec3(near(g, id), near(g, id + vec2(1.0, 0.0)), near(g, id + vec2(2.0, 0.0)));
}

// how much each site of a row counts in the group of the color c
vec3 alike(vec4 c, vec4 x, vec4 y, vec4 z, vec3 w) {
  vec4 dx = x - c, dy = y - c, dz = z - c;
  return w * exp(-0.5 * likeness * vec3(dot(dx, dx), dot(dy, dy), dot(dz, dz)));
}

struct Group {
  vec4 color;
  float strength;
};

Group group(vec4 c, vec4 c00, vec4 c01, vec4 c02, vec4 c10, vec4 c11, vec4 c12, vec4 c20, vec4 c21, vec4 c22, vec3 w0, vec3 w1, vec3 w2) {
  vec3 k0 = alike(c, c00, c01, c02, w0), k1 = alike(c, c10, c11, c12, w1), k2 = alike(c, c20, c21, c22, w2);
  vec4 sum = k0.x * c00 + k0.y * c01 + k0.z * c02 + k1.x * c10 + k1.y * c11 + k1.z * c12 + k2.x * c20 + k2.y * c21 + k2.z * c22;
  // the strongest group takes the pixel
  float strength = pow(dot(k0, k0) + dot(k1, k1) + dot(k2, k2), 40.0) * 1e8 + 1e-12;
  return Group(sum / dot(k0 + k1 + k2, vec3(1.0)), strength);
}

vec4 gathered(Group a, Group b, Group c) {
  return a.color * a.strength + b.color * b.strength + c.color * c.strength;
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float u = 1.0 - abs(2.0 * progress - 1.0);
  float s = 0.004 * pow(size / 0.004, smoothstep(0.0, 0.8, u));
  float turn = 0.5 + 0.7 * progress;
  vec2 r = vec2(cos(turn), sin(turn));
  vec2 p = (uv - 0.5) * asp / s;
  vec2 g = vec2(r.x * p.x - r.y * p.y, r.y * p.x + r.x * p.y);
  vec4 toUv = s * vec4(r.x, r.y, -r.y, r.x) / vec4(asp.xx, asp.yy);
  vec2 id0 = floor(g + 0.25) - 1.0;
  vec2 id1 = id0 + vec2(0.0, 1.0);
  vec2 id2 = id0 + vec2(0.0, 2.0);
  vec4 c00 = site(id0, toUv), c01 = site(id0 + vec2(1.0, 0.0), toUv), c02 = site(id0 + vec2(2.0, 0.0), toUv);
  vec4 c10 = site(id1, toUv), c11 = site(id1 + vec2(1.0, 0.0), toUv), c12 = site(id1 + vec2(2.0, 0.0), toUv);
  vec4 c20 = site(id2, toUv), c21 = site(id2 + vec2(1.0, 0.0), toUv), c22 = site(id2 + vec2(2.0, 0.0), toUv);
  vec3 w0 = nears(g, id0);
  vec3 w1 = nears(g, id1);
  vec3 w2 = nears(g, id2);
  Group g00 = group(c00, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2), g01 = group(c01, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2), g02 = group(c02, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2);
  Group g10 = group(c10, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2), g11 = group(c11, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2), g12 = group(c12, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2);
  Group g20 = group(c20, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2), g21 = group(c21, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2), g22 = group(c22, c00, c01, c02, c10, c11, c12, c20, c21, c22, w0, w1, w2);
  vec4 areas = gathered(g00, g01, g02) + gathered(g10, g11, g12) + gathered(g20, g21, g22);
  areas /= g00.strength + g01.strength + g02.strength + g10.strength + g11.strength + g12.strength + g20.strength + g21.strength + g22.strength;
  areas.rgb /= max(areas.a, 1e-4);
  return mix(progress < 0.5 ? getFromColor(uv) : getToColor(uv), areas, smoothstep(0.0, 0.15, u));
}
