// Author: gre
// License: MIT
// Description: The outgoing picture is squeezed into a slit of light that a prism spreads out into a rainbow across the whole frame; then the rainbow is gathered back into white light, and it is the incoming picture
// Tags: light, prism, rainbow, dispersion, optical
// Preview: 0.36

// @range(0, 1) Strength of the rainbow colors
uniform float saturation; // = 0.85
// @range(0.02, 0.3) Width of the slit when the rainbow is widest
uniform float slit; // = 0.2
// @range(0, 1) How much the prism bows the rainbow
uniform float bow; // = 0.6

const int TAPS = 30;

vec3 wavelength(float l) {
  vec3 a = (l - vec3(0.16, 0.47, 0.78)) / vec3(0.25, 0.22, 0.21);
  vec3 c = exp(-a * a);
  float v = (l - 1.0) / 0.12;
  c.r += 0.4 * exp(-v * v);
  // never 0, so that a narrow band still divides back to white
  return c + 0.004;
}

vec4 transition(vec2 uv) {
  float p = progress;
  float e = 1.0 - abs(2.0 * p - 1.0);
  e *= e * (3.0 - 2.0 * e);
  float d = pow(e, 2.4) * (1.0 - clamp(slit, 0.005, 0.9));
  float w = 1.0 - d;
  float dy = uv.y - 0.5;
  float x = uv.x - 0.5 + bow * d * w * dy * (dy + 0.8 * (1.0 - 2.0 * p));
  // what lies past the borders still lights them while the spread is small
  float reach = 0.5 * w + 0.6 * d * (1.0 - smoothstep(0.1, 0.5, d));
  float D = max(d, 1e-4);
  float lo = clamp((x - reach) / D + 0.5, 0.0, 0.97);
  float hi = clamp((x + reach) / D + 0.5, 0.03, 1.0);
  float m = smoothstep(0.43, 0.57, p) * 1.02 - 0.01;
  vec2 cell = floor(uv * vec2(ratio, 1.0) * 720.0);
  float jit = (fract(52.9829189 * fract(dot(cell, vec2(0.06711056, 0.00583715)))) - 0.5) * smoothstep(0.0, 0.2, d);
  vec4 acc = vec4(0.0);
  vec3 sum = vec3(0.0);
  for (int i = 0; i < TAPS; i++) {
    float l = mix(lo, hi, (float(i) + 0.5 + jit) / float(TAPS));
    vec2 at = vec2((x - d * (l - 0.5)) / w + 0.5, uv.y);
    at.x = 1.0 - abs(1.0 - mod(at.x, 2.0));
    vec3 s = wavelength(l);
    // each ray carries one of the pictures, so that the swap costs no extra read
    vec4 c;
    if (fract(float(i) * 0.618034 + 0.31) < m) c = getToColor(at);
    else c = getFromColor(at);
    acc += vec4(c.rgb * c.a * s, c.a);
    sum += s;
  }
  float n = float(TAPS);
  float alpha = acc.a / n;
  vec3 white = acc.rgb / sum;
  vec3 ray = mix(white, vec3(dot(white, vec3(0.333))), 0.7 * d * d);
  vec3 tint = sum / n;
  vec3 col = tint / mix(dot(tint, vec3(0.333)), max(max(tint.r, tint.g), tint.b), 0.6);
  col = mix(col, vec3(1.0), smoothstep(0.5, 1.0, hi - lo));
  vec3 rgb = mix(white, ray * (0.2 + 1.2 * col) + 0.1 * col * d * alpha, saturation * smoothstep(0.0, 0.45, d));
  return alpha > 0.0 ? vec4(min(rgb / alpha, 1.0), alpha) : vec4(0.0);
}
