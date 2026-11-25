// Author: gre
// License: MIT
// Description: The video loses its key frame: the pixels of the outgoing picture keep drifting along the motion of the incoming one, block by block, until its outlines and then the rest of it break through
// Tags: datamosh, codec, glitch, blocks, flow
// Preview: 0.5

// @param Number of rows of macroblocks
// @range(8, 60)
uniform float rows; // = 26.0
// @param Distance the pixels drift
// @range(0, 1)
uniform float drift; // = 0.6

const int STEPS = 12;

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float light(vec2 q) {
  return dot(getToColor(clamp(q, 0.0, 1.0)).rgb, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  vec2 n = floor(vec2(rows * ratio, rows));
  float e = progress * progress * (3.0 - 2.0 * progress);
  vec2 q = uv, hx = vec2(0.03 / ratio, 0.0), hy = vec2(0.0, 0.03);
  vec2 b = floor(uv * n);
  float l = light((b + 0.5) / n), busy = 0.0, left = 7.0;
  vec2 at = vec2(-1.0), g = vec2(0.0);
  for (int i = 0; i < STEPS; i++) {
    vec2 k = floor(q * n), c = (k + 0.5) / n;
    // the gradient is read again only in a new block
    if (left > 0.5 && k != at) {
      vec4 m = vec4(light(c + hx), light(c - hx), light(c + hy), light(c - hy));
      if (i == 0) busy = dot(abs(m - l), vec4(1.0));
      g = m.xz - m.yw;
      at = k;
      left -= 1.0;
    }
    vec2 w = c * a;
    vec2 pan = vec2(sin(3.1 * w.y + 1.0) + 0.6 * sin(5.0 * w.x), 0.8 * cos(3.7 * w.x + 0.4) + 0.5 * sin(6.0 * w.y));
    q = clamp(q - (0.6 * pan + 1.8 * vec2(-g.y, g.x) - 1.2 * g) / a * drift * e / float(STEPS), 0.0, 1.0);
  }
  float t = mix(0.66, 0.36, smoothstep(0.02, 0.5, busy)) + 0.16 * hash(b);
  return mix(getFromColor(q), getToColor(uv), smoothstep(0.0, 0.16, progress - t));
}
