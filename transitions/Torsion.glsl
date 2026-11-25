// Author: gre
// License: MIT
// Description: Twisting waves run out from the center, each ring of the outgoing image rocking against the next until its shapes stretch into circles of flame-like tongues; the incoming image comes in along the rings, which widen until they meet, and the rocking dies down on it
// Tags: twist, wave, rings, distortion, liquid

// @range(2, 12) Waves over the height of the frame
uniform float rings; // = 5.0
// @range(0, 2) How far the rings turn, in radians
uniform float turn; // = 0.7

const float TAU = 6.28318530718;
const int TAPS = 8;

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float env = smoothstep(0.0, 0.4, progress) * (1.0 - smoothstep(0.6, 1.0, progress));
  float level = 2.6 * smoothstep(0.1, 0.9, progress) - 1.3;
  vec4 sum = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    vec2 o = fract(vec2(0.754878, 0.569840) * (float(i) + 0.5)) - 0.5;
    vec2 x = (uv - 0.5) * asp + o * env / 450.0;
    float ph = TAU * (rings * length(x) - 2.5 * progress);
    float a = turn * env * sin(ph), c = cos(a), s = sin(a);
    vec2 q = fold(vec2(c * x.x - s * x.y, s * x.x + c * x.y) / asp + 0.5);
    sum += mix(premultiply(getFromColor(q)), premultiply(getToColor(q)), smoothstep(-0.06, 0.06, level + cos(ph)));
  }
  return vec4(sum.rgb / max(sum.a, 1e-5), sum.a / float(TAPS));
}
