// Author: gre
// License: MIT
// Description: Ferns of ice shoot out one after another across the outgoing picture and grow needle by needle until they meet; each needle is a clear facet that shows the incoming picture a little out of place, then the ice clears and every facet slides into line
// Tags: ice, crystal, frost, grow, refraction

// @range(0, 2) How much the ice bends the picture
uniform float bend; // = 1.0
// @range(0, 2) Light caught by the ice
uniform float shine; // = 1.0
// @range(0.6, 2) Size of the needles
uniform float size; // = 1.0

const int FERNS = 10;
const int TAPS = 2;

vec2 hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 look(vec2 uv) {
  float p = progress;
  // same area whatever the shape of the frame, so that the ice meets at the same time
  vec2 asp = vec2(ratio, 1.0) * 1.33 / sqrt(ratio);
  vec2 q = (uv - 0.5) * asp;
  float first = 9.0, edge = 0.0, seam = 1.0;
  vec2 dir = vec2(0.0);
  float freq = 18.0 / max(size, 0.1);
  for (int i = 0; i < FERNS; i++) {
    float fi = float(i);
    vec2 r = hash2(vec2(fi, 4.0)), r2 = hash2(vec2(fi, 14.0));
    vec2 c = (fract(vec2(0.7549, 0.5698) * (fi + 1.0)) - 0.5) * asp + 0.2 * (r - 0.5);
    float an = 1.0472 * floor(r2.x * 3.0) + 0.3 + 0.2 * r2.y;
    vec2 d = vec2(cos(an), sin(an)), n = vec2(-d.y, d.x);
    float x = dot(q - c, d), y = dot(q - c, n), ay = abs(y);
    float sx = x < 0.0 ? -1.0 : 1.0, sy = y < 0.0 ? -1.0 : 1.0;
    // needles leave the stem at 60 degrees, like real crystals
    float xb = abs(x) - 0.577 * ay;
    float k = xb * freq + r.y, f = fract(k);
    float tooth = abs(f - 0.5), off = smoothstep(0.0, 0.05, ay);
    float h = hash2(vec2(floor(k) + 40.0 * sx, fi + 20.0 * sy)).x;
    // smaller needles on the needles
    float barb = abs(fract(ay * 3.0 * freq + 1.5 * tooth) - 0.5);
    float tt = 0.035 * fi + abs(xb) * 0.3 + ay * (0.62 + 0.75 * h) + (0.15 + 0.07 * barb) * tooth * off;
    if (tt < first) {
      first = tt;
      vec2 bd = 0.5 * d * sx + 0.866 * n * sy;
      dir = vec2(-bd.y, bd.x) * (f - 0.5) + 0.35 * n * sy * smoothstep(0.0, 0.03, ay);
      seam = min(ay * 30.0, 1.0);
      edge = smoothstep(0.4, 0.5, tooth) * off;
    }
  }
  // the ice is slowed down once it has begun to meet, and hurries into the last corners
  float s = 1.0 - p, s2 = s * s, p3 = p * p * p;
  float age = 0.6 * p + 0.45 * p * s2 * s2 + 0.2 * p3 * p3 - 0.02 - first;
  float m = smoothstep(0.0, 0.006, age);
  float e = 1.0 - smoothstep(0.62, 1.0, p);
  vec4 a = pm(getFromColor(uv)), b = pm(getToColor(mirror(uv + bend * 0.1 * e * dir / asp)));
  float lit = dot(normalize(dir + 1e-4), vec2(-0.6, 0.8));
  float fresh = exp(-max(age, 0.0) * 22.0), cold = exp(-max(age, 0.0) * 5.0), glint = shine * e;
  b.rgb = mix(b.rgb, vec3(dot(b.rgb, vec3(0.299, 0.587, 0.114))), min((0.15 + 0.35 * cold) * glint, 1.0));
  b.rgb *= 1.0 + glint * (0.22 * lit + vec3(-0.1, 0.06, 0.2));
  b.rgb += (vec3(0.85, 0.96, 1.0) * b.a - b.rgb) * min(glint * (0.5 * fresh + 0.2 * (1.0 - seam) + 0.16 * edge + 0.1 * cold), 1.0);
  return mix(a, b, m);
}

vec4 transition(vec2 uv) {
  float spread = 0.0005 * min(1.0, 20.0 * progress * (1.0 - progress));
  vec4 c = vec4(0.0);
  for (int i = 0; i < TAPS; i++) c += look(uv + (float(i) - 0.5) * spread * vec2(1.0 / ratio, 0.7));
  return c.a > 0.0 ? vec4(min(c.rgb / c.a, 1.0), c.a / float(TAPS)) : vec4(0.0);
}
