// Author: gre
// License: MIT
// Description: A disc cut from the middle of the outgoing image makes a half turn, then the four discs inscribed in the quarters of the frame, then sixteen smaller ones; the smallest discs spin a full turn while the image changes to the incoming one, whose larger discs then turn back one size at a time until it is whole
// Tags: circle, rotate, recursive, graphic

// @range(2, 4, 1) Number of disc sizes: 1, 4, 16 then 64 discs
uniform int levels; // = 3
// @range(0, 1) Strength of the shadows the turning discs cast
uniform float shadow; // = 0.5

const float PI = 3.14159265;
// each turn lasts this many beats, so the next size starts before the previous one stops
const float D = 1.5;

float ease3(float x) {
  x = clamp(x, 0.0, 1.0);
  float y = 2.0 - 2.0 * x;
  return x < 0.5 ? 4.0 * x * x * x : 1.0 - 0.5 * y * y * y;
}

float bump(float x) { return sin(PI * clamp(x, 0.0, 1.0)); }

vec4 transition(vec2 uv) {
  float N = clamp(float(levels), 2.0, 4.0);
  float q = progress * (2.0 * N - 1.0 + D);
  vec2 asp = vec2(ratio, 1.0);
  vec2 p = uv;
  float lit = 1.0;
  float n = 8.0;
  for (int i = 3; i >= 0; i--) {
    float k = float(i);
    if (k >= N) {
      n *= 0.5;
      continue;
    }
    float a, m;
    if (k == N - 1.0) {
      float t = (q - k) / (1.0 + D);
      // fract brings the finished full turn back to exactly 0, sin(2 PI) is not 0 in floats
      a = 2.0 * PI * fract(ease3(t));
      m = bump(t);
    } else {
      float t0 = (q - k) / D, t1 = (q - (2.0 * N - 1.0 - k)) / D;
      a = PI * (ease3(t0) - ease3(t1));
      m = bump(t0) + bump(t1);
    }
    m = clamp(m, 0.0, 1.0);
    a *= mod(k, 2.0) < 0.5 ? 1.0 : -1.0;
    vec2 cc = (floor(p * n) + 0.5) / n;
    vec2 d = (p - cc) * asp;
    float R = 0.5 * min(ratio, 1.0) / n;
    float l = length(d);
    float aa = 0.002;
    float seam = 1.0 - smoothstep(0.0, aa, abs(l - R));
    lit *= 1.0 - seam * (0.2 * abs(sin(a * 0.5)) + 0.35 * m);
    // the shadow only falls in this disc's cell, so it fades out before the cell border
    vec2 cell = 0.5 * asp / n - abs(d);
    float ls = length(d - vec2(0.4, -0.6) * 0.06 * R);
    lit *= 1.0 - shadow * 0.6 * m * smoothstep(R - aa, R, l) * (1.0 - smoothstep(R * 0.85, R * 1.12, ls)) * smoothstep(0.0, 0.1 * R, min(cell.x, cell.y));
    if (l < R) {
      // the turn eases to 0 over the last pixels of the rim, which antialiases the cut
      float b = a * (1.0 - smoothstep(R - aa, R, l));
      float c = cos(b), s = sin(b);
      p += (mat2(c, s, -s, c) * d - d) / asp;
      lit *= 1.0 + 0.12 * m * smoothstep(R * 0.8, R, l) * dot(normalize(d + 1e-6), vec2(-0.6, 0.8));
    }
    n *= 0.5;
  }
  float x = smoothstep(N - 0.9, N + D - 0.1, q);
  vec4 col = mix(getFromColor(p), getToColor(p), x);
  col.rgb *= lit;
  return col;
}
