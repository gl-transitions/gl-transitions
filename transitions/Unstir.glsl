// Author: gre
// License: MIT
// Description: The outgoing picture is a liquid that whirls stir one after another, stretching it into curls, ribbons and fine marbled filaments; the filaments take the colors of the incoming picture and the stirring undoes itself, curl by curl, until the incoming picture is whole
// Tags: liquid, marbling, swirl, paint, distort

// @range(0, 12) How far each whirl turns the liquid, in radians
uniform float stir; // = 7.0
// @range(0.15, 0.45) Radius of the whirls, as a part of the frame's short side in a square frame
uniform float size; // = 0.28

const int TAPS = 12;
const int WHIRLS = 6;

vec2 mirrorUv(vec2 u) {
  return 1.0 - abs(1.0 - mod(u, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

float dye(vec2 x) {
  return 0.5 + 0.25 * sin(9.0 * x.x + 2.0 * sin(5.0 * x.y)) + 0.25 * sin(8.0 * x.y - 2.0 * sin(6.0 * x.x));
}

vec4 transition(vec2 uv) {
  vec2 s = vec2(ratio, 1.0) / min(ratio, 1.0);
  float r2 = size * size * max(s.x, s.y);
  float th = 1.12 - 1.24 * smoothstep(0.32, 0.68, progress);
  float env = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.85, 1.0, progress));
  vec2 pos[TAPS];
  for (int i = 0; i < TAPS; i++) {
    float fi = float(i);
    pos[i] = (uv - 0.5) * s + vec2(fract(fi * 0.618 + 0.3) - 0.5, (fi + 0.5) / float(TAPS) - 0.5) * 0.0035 * env;
  }

  // where the liquid came from: the whirls undone, last one first
  for (int j = 0; j < WHIRLS; j++) {
    float k = float(WHIRLS - 1 - j);
    // they peak one after another, so that some still wind while others unwind
    float peak = 0.37 + 0.05 * k;
    float t = smoothstep(0.02 * k, peak, progress) * (1.0 - smoothstep(peak, 0.9 + 0.02 * k, progress));
    float g0 = stir * t * (mod(k, 2.0) * 2.0 - 1.0);
    float a = 2.4 * k + 0.6;
    vec2 c = 0.34 * s * vec2(cos(a), sin(a));
    for (int i = 0; i < TAPS; i++) {
      vec2 d = pos[i] - c;
      float g = g0 * exp(-dot(d, d) / r2);
      float cg = cos(g) - 1.0, sg = sin(g);
      pos[i] += vec2(cg * d.x - sg * d.y, sg * d.x + cg * d.y);
    }
  }

  vec4 sum = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    vec2 u = mirrorUv(pos[i] / s + 0.5);
    sum += mix(pm(getFromColor(u)), pm(getToColor(u)), smoothstep(-0.1, 0.1, dye(pos[i]) - th));
  }
  return sum.a > 0.0 ? vec4(sum.rgb / sum.a, sum.a / float(TAPS)) : vec4(0.0);
}
