// Author: gre
// License: MIT
// Description: Waves run along the contours of the outgoing image as if every tone were swaying on its own beat; the contours bend to the shapes of the incoming image, which takes over crest by crest as the waves calm down
// Tags: wave, distortion, liquid, tones
// Preview: 0.5

// @range(0, 0.3) How wide the tones sway, in frame heights
uniform float swing; // = 0.1
// @range(5, 40) How many waves lie between black and white
uniform float waves; // = 18.0

const int TAPS = 12;

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

// a quadratic B-spline over a coarse lattice: smooth tones for 9 reads an image
float tone(vec2 uv, bool incoming) {
  vec2 n = 6.0 * vec2(ratio, 1.0) / min(ratio, 1.0);
  vec2 p = uv * n;
  vec2 c = floor(p) + 0.5;
  float s = 0.0;
  for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
      vec2 o = c + vec2(float(i), float(j));
      vec2 a = abs(p - o);
      vec2 w = mix(0.75 - a * a, 0.5 * (1.5 - a) * (1.5 - a), step(0.5, a));
      vec2 q = fold(o / n);
      vec4 t = incoming ? getToColor(q) : getFromColor(q);
      s += dot(t.rgb, vec3(0.299, 0.587, 0.114)) * t.a * w.x * w.y;
    }
  return s;
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float f = mix(tone(uv, false), tone(uv, true), smoothstep(0.1, 0.9, progress));
  // the slope across the frame keeps a plain sky from swaying and switching as one piece
  float ph = waves * f - 20.0 * progress + dot((uv - 0.5) * asp, vec2(4.0, 2.5));
  float amp = swing * smoothstep(0.0, 0.5, progress) * (1.0 - smoothstep(0.5, 1.0, progress));
  vec2 q = uv + amp * vec2(cos(ph), sin(ph)) / asp;
  float level = 2.2 * smoothstep(0.0, 1.0, progress) - 1.1 + 0.55 * cos(ph);
  vec4 sum = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float n = (float(i) + 0.5) / float(TAPS);
    float an = 2.399963 * float(i);
    vec2 r = fold(q + 0.04 * amp * sqrt(n) * vec2(cos(an), sin(an)) / asp);
    vec4 c = level + 0.03 * (n - 0.5) < 0.0 ? getFromColor(r) : getToColor(r);
    sum += vec4(c.rgb * c.a, c.a);
  }
  return vec4(sum.rgb / max(sum.a, 1e-5), sum.a / float(TAPS));
}
