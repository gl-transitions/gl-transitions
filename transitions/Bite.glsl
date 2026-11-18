// Author: gre
// License: MIT
// Description: The outgoing image is eaten like a cookie: bites are snapped out of its edges one after another, each deeper than the last and leaving a scalloped tooth-marked hole with a dark bitten rim, a jolt and falling crumbs, until a last big bite takes the rest and leaves the incoming image
// Tags: bite, eat, cookie, crumbs, playful

// @range(1, 9, 1) Number of bites before the last one
uniform int bites; // = 6
// @range(0, 1) How hard each bite jolts the image
uniform float jolt; // = 0.6
// @range(0, 1) Darkness of the bitten rims and of the shadow the image casts into the holes
uniform float shading; // = 0.6

const float START = 0.04;
const float LAST = 0.74;
const float SNAP = 0.06;
const float CRUMB_LIFE = 0.26;

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

float hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
             mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

float scale() {
  return min(ratio, 1.0);
}

float biteCount() {
  return clamp(float(bites), 1.0, 9.0);
}

float biteStart(float k) {
  return START + k * (LAST - START) / biteCount();
}

float biteRadius(float k) {
  return (0.28 + 0.22 * k / biteCount()) * scale();
}

vec2 biteDir(float k) {
  float a = 2.39996 * k + 0.6;
  return vec2(cos(a), sin(a));
}

// placed so the bite always cuts the frame edge, reaching deeper inside for later bites
vec2 biteCenter(float k) {
  vec2 d = biteDir(k);
  vec2 h = vec2(0.5 * ratio, 0.5);
  float e = min(h.x / max(abs(d.x), 1e-4), h.y / max(abs(d.y), 1e-4));
  float r = biteRadius(k);
  return h + d * (e + r - r * (0.55 + 0.6 * k / biteCount()));
}

// signed distance to a bite hole: one lobe per tooth, crumbly along the rim
float teeth(vec2 d, float r, float seed) {
  vec2 n = d / max(length(d), 1e-5);
  float lobes = abs(sin(atan(d.y, abs(d.x) < 1e-6 ? 1e-6 : d.x) * 12.0 + seed));
  return length(d) - r * (1.0 + 0.04 * lobes + 0.03 * noise(n * 9.0 + seed * 3.7));
}

// a snap, then a slow nibble until the last bite so the picture never freezes between bites
float growth(float t0) {
  float t = 1.0 - clamp((progress - t0) / SNAP, 0.0, 1.0);
  return 0.92 * (1.0 - t * t * t) + 0.08 * clamp((progress - t0) / (LAST - t0), 0.0, 1.0);
}

vec2 kick(float tau, vec2 toward) {
  return step(0.0, tau) * exp(-max(tau, 0.0) * 28.0) * sin(tau * 85.0) * toward;
}

vec4 transition(vec2 uv) {
  float s = scale();
  vec2 P = vec2(uv.x * ratio, uv.y);
  vec2 hc = vec2(0.5 * ratio, 0.5);
  vec2 off = vec2(0.012, -0.02) * s;
  vec2 cl = vec2(-0.12 * s, 0.9);
  float rl = length(vec2(ratio, 0.0) - cl) + 0.1;
  float tl = 1.0 - clamp((progress - LAST) / (1.0 - LAST), 0.0, 1.0);
  // slower than a snap: the giant radius would otherwise clear the frame long before the end
  float lastGrowth = 1.0 - tl * tl;

  vec2 shake = kick(progress - LAST, normalize(cl - hc));
  for (int k = 0; k < 9; k++) {
    float fk = float(k);
    if (fk >= biteCount()) break;
    shake += kick(progress - biteStart(fk), biteDir(fk));
  }
  vec2 Q = P - shake * 0.018 * jolt * s;

  float dm = teeth(Q - cl, rl * lastGrowth, 3.0) + 0.05 * (1.0 - lastGrowth);
  float sh = teeth(Q - off - cl, rl * lastGrowth, 3.0) + 0.05 * (1.0 - lastGrowth);
  vec2 crumbUV = vec2(0.0);
  float crumbShade = 1.0;
  float ca = 0.0;
  for (int k = 0; k < 9; k++) {
    float fk = float(k);
    if (fk >= biteCount()) break;
    float t0 = biteStart(fk);
    if (progress < t0) break;
    float g = growth(t0);
    vec2 c = biteCenter(fk);
    float r = biteRadius(fk);
    // the 0.05 lift keeps a just-started bite closed until it has grown past it
    dm = min(dm, teeth(Q - c, r * g, fk) + 0.05 * (1.0 - g));
    sh = min(sh, teeth(Q - off - c, r * g, fk) + 0.05 * (1.0 - g));

    float tau = progress - t0;
    if (tau > 0.0 && tau < CRUMB_LIFE) {
      vec2 inward = hc - c;
      float base = atan(inward.y, inward.x);
      for (int j = 0; j < 5; j++) {
        float fj = float(j);
        float h1 = hash(fk * 7.13 + fj * 1.37);
        float h2 = hash(fk * 3.71 + fj * 5.19 + 11.0);
        float h3 = hash(fk * 9.17 + fj * 2.31 + 23.0);
        float a = base + (h1 - 0.5) * 1.6;
        vec2 o = c + vec2(cos(a), sin(a)) * r * g * 0.98;
        vec2 pos = o + vec2((h2 - 0.5) * 0.5, 0.25 * h3) * tau * s - vec2(0.0, 3.2 * tau * tau);
        float sz = (0.007 + 0.01 * h3) * s;
        float rot = h2 * 6.283 + tau * (h1 - 0.5) * 30.0;
        vec2 q = mat2(cos(rot), sin(rot), -sin(rot), cos(rot)) * (Q - pos);
        float cd = mix(length(q), max(abs(q.x), abs(q.y * 1.3)), 0.6) - sz;
        float m = (1.0 - smoothstep(-0.0015, 0.0015, cd)) * smoothstep(0.0, SNAP, tau) * (1.0 - smoothstep(0.6 * CRUMB_LIFE, CRUMB_LIFE, tau));
        if (m > ca) {
          ca = m;
          crumbUV = o / vec2(ratio, 1.0);
          crumbShade = 0.62 + 0.3 * clamp(0.5 + 0.5 * q.y / sz, 0.0, 1.0);
        }
      }
    }
  }

  vec4 a = getFromColor(mirror(Q / vec2(ratio, 1.0)));
  float rimW = 0.016 * s;
  float rim = 1.0 - smoothstep(0.0, rimW, dm);
  a.rgb *= 1.0 - shading * 0.55 * rim * rim * (0.7 + 0.3 * noise(Q * 60.0));
  vec4 b = getToColor(uv);
  float caster = getFromColor(mirror((Q - off) / vec2(ratio, 1.0))).a;
  b.rgb *= 1.0 - shading * 0.5 * caster * smoothstep(-0.035, 0.01, sh);

  float cover = clamp(dm * 400.0 + 0.5, 0.0, 1.0);
  vec4 col = mix(vec4(b.rgb * b.a, b.a), vec4(a.rgb * a.a, a.a), cover);
  vec4 cr = getFromColor(mirror(crumbUV));
  cr.a *= ca;
  col = vec4(cr.rgb * crumbShade * cr.a, cr.a) + col * (1.0 - cr.a);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
