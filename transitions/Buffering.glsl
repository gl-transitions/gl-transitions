// Author: gre
// License: MIT
// Description: Five dots of the incoming picture pop up in a row and hop in a staggered wave like a loading indicator, stretching in the air and squashing on landing, then huddle together, melt into one gooey bar and swell into the full frame
// Tags: dots, bounce, liquid, graphic, reveal

// @range(0, 0.15) How far apart dots reach to melt into each other
uniform float gooeyness; // = 0.08

const float AA = 0.003;
const float PI = 3.14159265;

float smin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

vec4 transition(vec2 uv) {
  // the row of dots shrinks only when the frame is too narrow to hold it
  float sc = min(ratio / 1.4, 1.0);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0) / sc;
  float t = progress;
  float gather = smoothstep(0.25, 0.75, t);
  float swell = smoothstep(0.5, 1.0, t);
  float gap = mix(0.25, 0.15, gather);
  float amp = 0.2 * (1.0 - smoothstep(0.45, 0.8, t));
  float r0 = mix(-0.03, 0.075, smoothstep(0.0, 0.12, t)) + 0.02 * gather;
  // just reaches the far corners from the outer dots at the very end, so the swell never stalls
  float reach = length(vec2(0.5 * ratio / sc - 0.3, 0.5 / sc)) - 0.085;
  float r = r0 + swell * swell * reach;
  float goo = max(gooeyness, 1e-4);
  float d = 1e3;
  for (int i = 0; i < 5; i++) {
    float f = float(i) - 2.0;
    float ph = 2.6 * t - 0.11 * (f + 2.0);
    float s = sin(2.0 * PI * ph);
    float hop = max(s, 0.0);
    // stretched while in the air, squashed while on the floor
    float st = 1.0 + amp / 0.2 * (0.3 * abs(cos(2.0 * PI * ph)) * min(hop * 4.0, 1.0) - 0.25 * max(-s, 0.0));
    vec2 c = vec2(f * gap, amp * (hop - 0.4));
    vec2 q = (p - c) * vec2(st, 1.0 / st);
    d = smin(d, length(q) - r, goo);
  }
  float m = 1.0 - smoothstep(-AA, AA, d);
  vec2 zu = 0.5 + (uv - 0.5) / mix(1.12, 1.0, swell);
  return mix(getFromColor(uv), getToColor(zu), m);
}
