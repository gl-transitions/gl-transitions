// Author: gre
// License: MIT
// Description: The outgoing image's dark and light areas run together into two large flat masses of its own colors, edged by a band of their middle tone; the masses travel across the frame, merge and part, carrying their colors along, until they settle where the incoming image is dark and light and its shapes come out of them
// Tags: masses, flat, tone, organic, palette, abstract
// Preview: 0.4

// @range(5, 30) How tight the masses are
uniform float tightness; // = 11.0

const int N = 12;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 spot(float i) {
  return (fract(vec2(0.754878, 0.569840) * i + 0.4) - 0.5) * vec2(0.92, 0.88) + 0.5;
}

// where spot i of the outgoing image goes in the incoming one
float partner(float i) {
  return mod(i * 5.0 + 4.0, 12.0);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec2 asp = vec2(ratio, 1.0);
  vec2 p = uv * asp;
  float bend = smoothstep(0.02, 0.32, progress) * (1.0 - smoothstep(0.68, 0.98, progress));
  float soft = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  bool late = progress > 0.5;

  vec2 mean = vec2(0.0);
  for (int i = 0; i < N; i++) {
    float f = float(i);
    mean += vec2(luma(getFromColor(spot(f)).rgb), luma(getToColor(spot(partner(f))).rgb));
  }
  mean /= float(N);

  float tight = tightness * 1.6 / ratio;
  vec2 sums = vec2(0.0);
  float dark = 1e-3;
  float light = 1e-3;
  vec4 cd = vec4(0.0);
  vec4 cl = vec4(0.0);
  for (int i = 0; i < N; i++) {
    float f = float(i);
    vec4 ca = getFromColor(spot(f));
    vec4 cb = getToColor(spot(partner(f)));
    float t = smoothstep(0.06 + 0.03 * f, 0.6 + 0.03 * f, progress);
    vec2 m = mix(spot(f), spot(partner(f)), t);
    vec2 q = m * asp + 0.18 * min(ratio, 1.3) * sin(3.14159 * t) * vec2(cos(f * 2.4), sin(f * 2.4));
    float v = clamp(mix(luma(ca.rgb) - mean.x, luma(cb.rgb) - mean.y, t) * 6.0, -1.2, 1.2);
    vec2 pull = vec2(exp(-2.0 * v), exp(2.0 * v));
    sums += pull;
    vec2 d = p - q;
    float g = exp(-tight * dot(d, d));
    dark += g * pull.x;
    light += g * pull.y;
    // colors spread wider than the masses, so a mass never runs out of color
    vec4 c = vec4(mix(ca.rgb, cb.rgb, smoothstep(0.3, 0.7, t)), 1.0) * exp(-0.5 * tight * dot(d, d));
    cd += c * pull.x;
    cl += c * pull.y;
  }

  float y = 0.0;
  for (int i = 0; i < 6; i++) {
    float n = float(i) * 1.0472;
    vec2 q = fold(uv + (0.015 + 0.015 * mod(float(i), 2.0)) * soft * vec2(cos(n), sin(n)) / asp);
    y += luma(late ? getToColor(q).rgb : getFromColor(q).rgb) / 6.0;
  }
  float h = mix((y - (late ? mean.y : mean.x)) * 5.0, log(light / dark * sums.x / sums.y), bend);
  float aa = mix(0.12, 0.06, bend);
  vec3 dk = cd.rgb / max(cd.a, 1e-6);
  vec3 lt = cl.rgb / max(cl.a, 1e-6);
  dk = clamp(max(luma(dk) * 0.75 + 0.02, 0.17) + (dk - luma(dk)) * 1.3, 0.0, 1.0);
  lt = clamp(luma(lt) * 0.8 + 0.22 + (lt - luma(lt)) * 1.3, 0.0, 1.0);
  vec3 col = mix(dk, lt, smoothstep(-aa, aa, h));
  col = mix(col, mix(dk, lt, 0.5), (1.0 - smoothstep(-aa, aa, abs(h) - 0.5)) * 0.9);

  vec4 photo = mix(a, b, smoothstep(0.4, 0.6, progress));
  float l = clamp(y, 0.0, 1.0);
  float ink = smoothstep(0.0, 0.16, progress - 0.06 * l) * smoothstep(0.0, 0.22, mix(1.0, 0.88, l) - progress);
  return vec4(mix(photo.rgb, col, ink), photo.a);
}
