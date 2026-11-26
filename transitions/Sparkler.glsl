// Author: gre
// License: MIT
// Description: A crackling sparkler writes a looping joined-up line across the outgoing image; its glowing trail shows the incoming image, and the written loops swell and merge behind the spitting tip until they fill the frame
// Tags: sparkler, fireworks, sparks, handwriting, celebration, reveal

// @range(2.0, 8.0) Number of loops the sparkler writes across the frame
uniform float loops; // = 5.0
// @range(0.0, 2.0) Strength of the sparks and the hot glow of the trail
uniform float sparks; // = 1.0
// @color Color of the sparks and of the hot rim of the trail
uniform vec4 sparkColor; // = vec4(1.0, 0.78, 0.4, 1.0)

const float PI = 3.141592653589793;
const int SEG = 64;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// a prolate cycloid: the looping stroke of joined-up handwriting
vec2 path(float s) {
  float w = 2.0 * PI * loops * s;
  return vec2((0.05 + 0.95 * s) * ratio - 0.13 * sin(w), 0.5 + 0.17 * cos(w) + 0.12 * sin(2.0 * PI * 1.3 * s));
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float head = clamp(progress / 0.62, 0.0, 1.0);
  vec2 tip = path(head);
  // narrow frames fill sooner: slow the swelling so portrait keeps moving to the end
  float fill = min(ratio, 1.0);
  float sd = 1e3;
  float glowAge = 1.0;
  float dw = 2.0 * PI * loops / float(SEG);
  float dv = 2.0 * PI * 1.3 / float(SEG);
  mat2 rw = mat2(cos(dw), sin(dw), -sin(dw), cos(dw));
  mat2 rv = mat2(cos(dv), sin(dv), -sin(dv), cos(dv));
  // path() stepped by rotating its two phases instead of calling sin/cos per segment
  vec2 cs = vec2(1.0, 0.0);
  vec2 cv = vec2(1.0, 0.0);
  vec2 a = path(0.0);
  for (int k = 1; k <= SEG; k++) {
    float s1 = float(k) / float(SEG);
    float s0 = s1 - 1.0 / float(SEG);
    cs = rw * cs;
    cv = rv * cv;
    if (s0 >= head) break;
    vec2 b = s1 < head ? vec2((0.05 + 0.95 * s1) * ratio - 0.13 * cs.y, 0.5 + 0.17 * cs.x + 0.12 * cv.y) : tip;
    float se = min(s1, head);
    vec2 ab = b - a;
    float h = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    float age = progress - mix(s0, se, h) * 0.62;
    float w = 0.006 * smoothstep(0.0, 0.02, age) + (0.08 * age + 1.4 * age * age) * fill;
    float d = length(q - a - ab * h) - w;
    if (d < sd) {
      sd = d;
      glowAge = age;
    }
    a = b;
  }
  float px = 1.5 / 600.0;
  float cover = 1.0 - smoothstep(-px, px, sd + px);
  cover = max(cover, smoothstep(0.8, 1.0, progress));
  vec4 col = mix(getFromColor(uv), getToColor(uv), cover);

  float live = (1.0 - smoothstep(0.7, 1.0, progress)) * smoothstep(0.005, 0.04, progress) * sparks;
  float rim = exp(-abs(sd) * 160.0) * exp(-glowAge * 9.0) * live;
  vec2 dt = q - tip;
  float r = length(dt);
  // integer multiples of the angle keep the rays continuous across atan's branch cut
  float ang = atan(dt.y, dt.x);
  float flick = floor(progress * 90.0);
  float rays = pow(max(cos(ang * 7.0 + hash12(vec2(flick, 1.0)) * 6.28), 0.0), 30.0)
             + pow(max(cos(ang * 11.0 + hash12(vec2(flick, 2.0)) * 6.28), 0.0), 40.0);
  float spark = (rays * exp(-r * 22.0) + exp(-r * 90.0) * 2.0) * live * (1.0 - smoothstep(0.97, 1.0, head));
  col.rgb += (rim * 1.2 + spark) * sparkColor.rgb * sparkColor.a;
  return col;
}
