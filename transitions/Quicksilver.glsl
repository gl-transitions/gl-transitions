// Author: gre
// License: MIT
// Description: Beads of mercury well up on the outgoing picture, each a curved mirror with the whole incoming picture in it; they tremble, roll together and run into one pool, whose sheet spreads over the frame with the last beads still rolling into it, then goes flat until its reflection is the picture itself
// Tags: mirror, liquid, metal, reflection, optical
// Preview: 0.4

// @range(0, 1) How metallic the reflection looks where the mercury is curved
uniform float chrome; // = 0.85
// @range(0.5, 1.5) Size of the beads
uniform float beadSize; // = 1.0
// @range(0, 1) Darkness of the shadow around the mercury
uniform float shadow; // = 0.5

const int BEADS = 15;
// how tightly the beads join
const float K = 22.0;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec2 hash(float i) {
  vec3 q = fract(vec3(i + 3.7) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.xx + q.yz) * q.zy);
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// xy: gradient, z: signed distance, w: radius of the mercury around
vec4 mercury(vec2 q, vec2 asp) {
  float p = progress;
  float sum = 1e-9;
  vec3 acc = vec3(0.0);
  for (int i = 0; i < BEADS; i++) {
    float fi = float(i);
    vec2 h = hash(fi);
    float a = 2.39996 * fi + 0.8;
    vec2 home = 0.53 * asp * sqrt((fi + 0.4) / float(BEADS)) * vec2(cos(a), sin(a));
    float at = 0.2 + 0.3 * length(home) + 0.12 * h.y;
    float g = clamp((p - at) / 0.42, 0.0, 1.0);
    g *= g * (1.5 - 0.5 * g);
    float twist = 0.9 * g * (1.0 - g);
    vec2 c = home * (1.0 - g) + twist * vec2(-home.y, home.x);
    c += 0.012 * vec2(sin(p * 21.0 + 6.28 * h.x), cos(p * 17.0 + 6.28 * h.y));
    float born = clamp((p - 0.12 * h.x) / 0.2, 0.0, 1.0);
    born *= 2.0 - born;
    float r = mix(-0.06, (0.065 + 0.06 * h.y) * beadSize, born);
    if (i == 0) {
      c *= 1.0 - smoothstep(0.1, 0.4, p);
      float s = clamp((p - 0.2) / 0.72, 0.0, 1.0);
      r += (0.5 * length(asp) + 0.5) * s * s * (0.45 + 0.55 * s);
    }
    vec2 d = q - c;
    // rounded at the center, where the distance has no slope
    float l = sqrt(dot(d, d) + 0.0004);
    r += 0.004 * sin(3.0 * p * 14.0 + 5.0 * d.x / l + fi) * born * (1.0 - p);
    float w = exp(clamp(K * (r - l), -60.0, 60.0));
    sum += w;
    acc += w * vec3(d / l, max(r, 0.0));
  }
  return vec4(acc.xy / sum, -log(sum) / K, acc.z / sum);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // as many beads of the same shape in any frame
  vec2 asp = vec2(ratio, 1.0) / sqrt(ratio / 1.6);
  vec2 q = (uv - 0.5) * asp;
  vec4 f = mercury(q, asp);
  float d = f.z;
  float m = 1.0 - smoothstep(-0.0015, 0.0015, d);

  float calm = 1.0 - smoothstep(0.6, 1.0, p);
  float dome = clamp(f.w, 0.03, 0.2);
  float s = clamp(1.0 + d / dome, 0.0, 1.0);
  vec2 slope = f.xy * s * s * (0.6 + 0.4 * s) * 0.97;
  float lr = length(q);
  vec2 ring = q / max(lr, 1e-3);
  slope += calm * smoothstep(0.1, 0.4, f.w) * (1.0 - s) * 0.13 * (ring * sin(lr * 34.0 - p * 60.0) * smoothstep(0.0, 0.3, lr) + 0.5 * vec2(sin(q.y * 13.0 + p * 25.0), sin(q.x * 11.0 - p * 22.0)));
  slope *= smoothstep(0.0, 0.15, 1.0 - p);
  float sl = dot(slope, slope);
  slope *= min(1.0, 0.97 / sqrt(max(sl, 1e-6)));
  vec3 n = vec3(slope, sqrt(max(1.0 - dot(slope, slope), 0.0)));

  // a small bead holds the whole picture around its own middle, the sheet only what is above it
  vec2 base = mix(vec2(0.5), uv, smoothstep(0.1, 0.3, f.w));
  vec2 at = base + n.xy * (0.4 + 0.16 * n.z);
  // a curved mirror shrinks what it shows
  float px = 0.02 * length(n.xy);
  vec4 b = 0.2 * (pm(getToColor(mirror(at))) + pm(getToColor(mirror(at + px))) + pm(getToColor(mirror(at - px)))
    + pm(getToColor(mirror(at + vec2(px, -px)))) + pm(getToColor(mirror(at + vec2(-px, px)))));
  float bent = smoothstep(0.1, 0.75, length(n.xy));
  float lum = dot(b.rgb, vec3(0.3, 0.59, 0.11));
  float sky = 2.0 * n.y * n.z;
  vec3 metal = mix(vec3(0.1, 0.12, 0.16), vec3(0.96, 0.98, 1.0), smoothstep(-0.1, 1.0, lum + 0.35 * sky)) * b.a;
  b.rgb = mix(b.rgb, metal * 0.8 + b.rgb * 0.3, chrome * bent);
  // dark line where the mirror turns away
  b.rgb *= 1.0 - 0.6 * smoothstep(0.85, 0.97, length(n.xy));
  float spec = pow(max(dot(n, normalize(vec3(-0.4, 0.5, 0.75))), 0.0), 70.0);
  b.rgb += spec * 0.9 * smoothstep(0.05, 0.3, length(n.xy)) * b.a;

  vec4 a = pm(getFromColor(uv));
  float sd = mercury(q + vec2(-0.01, 0.018), asp).z;
  a.rgb *= 1.0 - shadow * smoothstep(0.03, 0.07, f.w) * (1.0 - smoothstep(-0.02, 0.07, sd));
  vec4 c = mix(a, b, m);
  return c.a > 0.0 ? vec4(min(c.rgb / c.a, 1.0), c.a) : vec4(0.0);
}
