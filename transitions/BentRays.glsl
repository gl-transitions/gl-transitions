// Author: gre
// License: MIT
// Description: The outgoing image is drawn out into flat rays of its own colors that zigzag in and out from the center like a jagged star; the star turns and keeps growing, the colors of the incoming image open along every ray, and the zigzags straighten out into it
// Tags: rays, zigzag, star, flat-color, geometric
// Preview: 0.5

// @range(6, 24, 1) Rays around the center
uniform float rays; // = 12.0
// @range(-1, 1) Turns made by the star
uniform float turns; // = 0.25

const float TAU = 6.28318530718;

float stair(float s, float m) {
  float f = 2.0 * fract(s) - 1.0;
  return floor(s) + 0.5 + 0.5 * sign(f) * pow(abs(f), m);
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float count = max(floor(rays + 0.5), 1.0);
  float k = smoothstep(0.0, 0.4, progress) * (1.0 - smoothstep(0.6, 1.0, progress));
  float m = 1.0 / max(1.0 - k, 0.03);
  // once flat, colors average a small area so that single pixels don't flicker
  float soft = 16.0 * pow(k, 8.0);
  float spin = TAU * turns * progress;
  vec4 sum = vec4(0.0);
  for (int i = 0; i < 16; i++) {
    vec2 o = (vec2(mod(float(i), 4.0), floor(float(i) / 4.0)) - 1.5) / 1200.0;
    vec2 p = (uv - 0.5) * asp + o * k;
    float lr = log(max(length(p), 1e-3) / 0.4) / 0.7 - 1.1 * progress;
    float odd = mod(floor(lr), 2.0);
    // tangents to nested circles, every other ring leaning back so that the rays join into zigzags
    float a = atan(p.y, p.x) + (1.0 - 2.0 * odd) * (acos(exp(-0.7 * fract(lr))) - 1.0519 * odd);
    float b = (a - spin) / TAU * count;
    float g = smoothstep(0.0, 0.3, progress - 0.25 - 0.2 * fract(mod(floor(b), count) * 0.618));
    bool late = fract(b) < g * 1.02 - 0.01;
    a = stair(b, m) / count * TAU + spin;
    vec2 q = vec2(cos(a), sin(a)) * (0.4 - 0.12 * progress);
    q = mix(p, q, k) / asp + 0.5 + soft * o;
    q = 1.0 - abs(1.0 - mod(q, 2.0));
    vec4 c = late ? getToColor(q) : getFromColor(q);
    sum += vec4(c.rgb * c.a, c.a);
  }
  return vec4(sum.rgb / max(sum.a, 1e-5), sum.a / 16.0);
}
