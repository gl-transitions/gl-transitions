// Author: gre
// License: MIT
// Description: The outgoing picture grows a thick coat of fur and shakes itself like a wet animal: the skin rolls from side to side, the long hair whips after it, and each lash leaves more of the coat in the colors of the incoming picture, which settles and grows smooth again
// Tags: fur, shake, animal, playful, organic

// @range(0.04, 0.16) Length of the fur, in frame heights
uniform float fur; // = 0.13
// @range(40, 100) Hairs across the height of the frame
uniform float density; // = 80.0
// @range(0, 1) Strength of the shake
uniform float shake; // = 0.6

const float TAU = 6.2831853;
const int LAYERS = 18;

vec2 hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  // a small offset, so that fract loses fewer bits
  p3 += dot(p3, p3.yzx + 7.31);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x),
             mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, f.x), f.y);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 image(vec2 st, float s) {
  vec4 a = getFromColor(st);
  vec4 b = getToColor(st);
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), s);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float g = smoothstep(0.0, 0.24, p) * (1.0 - smoothstep(0.74, 1.0, p));
  float e = smoothstep(0.14, 0.36, p) * (1.0 - smoothstep(0.6, 0.88, p));
  float ph = TAU * 2.5 * p;

  vec2 q = (uv - 0.5) * asp;
  // the twist runs down the body from the head
  float lag = 1.5 * q.y;
  float roll = shake * e * sin(ph + lag);
  float whip = shake * e * sin(ph + lag - 1.1);
  q.x -= 0.09 * roll;
  q.y -= 0.03 * shake * e * cos(ph + lag) * q.x;

  vec2 lie = vec2(1.1 * (noise(q * 2.3 + 11.0) - 0.5), -0.75 + 0.5 * (noise(q * 2.0 + 7.0) - 0.5));
  lie.x += 1.5 * whip;
  // long from the first frames: stubs seen from above look like a weave
  lie *= fur * mix(0.4, 1.0, g);

  float n = max(density, 10.0);
  float cover = 0.0;
  float hh = 0.0, across = 0.0, tuft = 0.0, id = 0.0;
  vec2 shift = vec2(0.0);
  for (int i = 0; i < LAYERS; i++) {
    float h = 1.0 - (float(i) + 0.5) / float(LAYERS);
    vec2 at = q - lie * h * sqrt(h);
    // tips lean toward the middle of their tuft
    vec2 cl = floor(at * n / 7.0);
    vec2 dc = at - (cl + 0.25 + 0.5 * hash2(cl + 103.0)) * 7.0 / n;
    at += dc * 0.45 * h * h;
    vec2 g2 = at * n;
    float row = floor(g2.y);
    float slide = hash2(vec2(row, 57.0)).x;
    g2.x += slide;
    vec2 c = floor(g2);
    vec2 r2 = hash2(c + 31.0);
    vec2 o = g2 - c - 0.3 - 0.4 * r2;
    float len = 0.5 + 0.5 * fract(r2.x * 7.3 + r2.y * 3.1);
    float rad = 0.62 * (1.0 - h / len);
    if (rad > 0.0) {
      // stretched over the gap to the next layer, or the hairs break up into dots
      vec2 v = lie * n * 1.5 * sqrt(h) / float(LAYERS);
      o -= v * clamp(dot(o, v) / max(dot(v, v), 1e-5), -0.5, 0.5);
      float m = (1.0 - cover) * clamp(0.5 + (rad - length(o)) * 6.0, 0.0, 1.0) * smoothstep(0.0, 0.1, rad);
      cover += m;
      hh += m * h;
      across += m * o.x / rad;
      tuft += m * length(dc) * n / 7.0;
      id += m * r2.y;
      shift += m * ((c + 0.5 - vec2(slide, 0.0)) / n - q);
    }
    if (cover > 0.97) break;
  }
  id += 0.5 * (1.0 - cover);
  vec2 root = q + shift;
  vec2 st = mirror((q + g * shift) / asp + 0.5);
  float when = 0.34 + 0.32 * (0.65 * noise(root * 4.0 + 20.0) + 0.35 * id);
  // turns over in bursts, where the whip is fastest
  float clock = p + 0.03 * shake * e * sin(2.0 * (ph + lag - 1.1));
  float s = smoothstep(when - 0.05, when + 0.05, clock + 0.06 * (hh - 0.5));
  vec4 col = image(st, s);

  float lit = mix(0.45, 1.12, smoothstep(0.0, 0.6, hh)) * mix(0.82, 1.12, id) * (1.0 - 0.35 * smoothstep(0.2, 0.8, tuft) * hh);
  lit *= 1.0 - 0.16 * roll * sin(q.x * 3.0);
  float sheen = max(0.0, 1.0 - abs(across + 0.35));
  vec3 furry = col.rgb * lit + 0.18 * sheen * sheen * hh * (0.3 * col.a + col.rgb);
  return vec4(mix(col.rgb, furry, g), col.a);
}
