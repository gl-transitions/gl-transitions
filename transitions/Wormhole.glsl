// Author: gre
// License: MIT
// Description: A small glass-like sphere opens in the outgoing picture and bends the scene around it, with the incoming world visible inside; the camera falls through its mouth and comes out into the incoming picture
// Tags: wormhole, space, lens, travel, distort

// @range(-1, 1) How much the bent light twists around the mouth
uniform float swirl; // = 0.5
// @range(0, 1) Brightness of the ring of light around the mouth
uniform float ring; // = 0.6

const float PI = 3.14159265;
const int STEPS = 16;

vec2 mirrored(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// levels off past the frame's corners (1.39 rad with the field below) so the repeats near the rim stay calm
float skyRadius(float th) {
  float k = 1.2 * max(th - 1.4, 0.0);
  return th < 1.4 ? tan(0.5 * th) : tan(0.7) + 0.7 * k / (1.0 + k);
}

// the curved space only has a scale through the mouth's apparent half angle A
vec4 trace(float rs, vec2 dir, float A, float field) {
  vec2 asp = vec2(ratio, 1.0);
  float b = max(sin(A), 0.0);
  float l0 = cos(A);
  float al = 2.0 * atan(rs / (2.0 * field));
  float L = sin(al);
  float m2 = (L - b) * (L + b);
  bool through = m2 < 0.0;
  // both smooth substitutions are singular at the critical ray, harmless once the throat is behind
  bool crit = l0 < 0.0 && abs(m2) < 0.3 * b * b;
  float x0 = 0.0, x1 = 1.0;
  if (!crit) {
    if (through) {
      x0 = -0.5 * PI;
      x1 = atan(l0, sqrt(-m2));
    } else {
      float psi = asin(clamp(sqrt(m2) / max(abs(l0), 1e-4), 0.0, 1.0));
      x0 = l0 > 0.0 ? psi : 0.0;
      x1 = l0 > 0.0 ? PI : psi;
    }
  }
  // angle swept along a null geodesic of ds2 = dl2 + (b2 + l2) dO2
  float w = (x1 - x0) / float(STEPS);
  float phi = 0.0;
  for (int i = 0; i < STEPS; i++) {
    float x = x0 + (float(i) + 0.5) * w;
    float s = sin(x);
    float h = 1.0 - x;
    float l = x - l0 * h;
    phi += crit
      ? L / sqrt(max((l * l + b * b * h * h) * (l * l - m2 * h * h), 1e-9))
      : L / sqrt(max(through ? b * b - L * L * s * s : m2 + b * b * s * s, 0.02 * b * b + 1e-9));
  }
  phi *= w;
  bool other = through || l0 < 0.0;
  float th = other ? phi : PI - phi;
  float bend = th - al;
  float a = swirl * 2.0 * bend / (1.0 + abs(bend));
  vec2 e = mat2(cos(a), sin(a), -sin(a), cos(a)) * dir;
  // a negative angle is the far side of the axis: the mirrored inner image
  vec2 q = e * sign(th) * skyRadius(abs(th)) * 2.0 * field;
  if (other) {
    // the far world is squeezed into the mouth instead of repeating in it
    vec2 k = 1.8 / asp * (1.0 - smoothstep(0.7, 2.7, A));
    q /= sqrt(1.0 + q * q * k * k);
  }
  vec2 st = mirrored(0.5 + q / asp);
  vec4 c = other ? getToColor(st) : getFromColor(st);

  float off = (L - b) / (0.03 + 0.1 * b);
  float edge = smoothstep(0.0, 0.12, b) * smoothstep(0.0, 0.3, l0);
  c.rgb *= 1.0 - 0.35 * edge * exp(-abs(off) * 0.6) * (through ? 1.0 : 0.6);
  c.rgb = min(c.rgb + ring * edge * (0.25 + 0.75 * c.rgb) * exp(-off * off * 5.0), 1.0);
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // still moving at the end: the last of the bending fades like the square of what is left
  float A = PI * p * p * (2.0 - p);
  vec2 asp = vec2(ratio, 1.0);
  float field = 0.3 * length(asp);
  vec2 d = (uv - 0.5) * asp;
  // kept off the axis, where the deflection of a closed mouth is 0 / 0
  float rs = max(length(d), 1e-4);
  vec2 dir = length(d) > 1e-5 ? normalize(d) : vec2(1.0, 0.0);
  // radial samples around the rim, where the images wind up endlessly
  float rim = 2.0 * field * tan(0.5 * min(A, 1.6));
  float dr = 0.0014 * exp(-abs(rs - rim) / (0.02 + 0.06 * rim)) * smoothstep(0.0, 0.15, A) * (1.0 - smoothstep(1.4, 1.6, A));
  vec4 c = trace(rs, dir, A, field);
  if (dr > 1e-4) {
    c += trace(max(abs(rs - dr), 1e-4), rs < dr ? -dir : dir, A, field) + trace(rs + dr, dir, A, field);
    c /= 3.0;
  }
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
