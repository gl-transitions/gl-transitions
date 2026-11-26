// Author: gre
// License: MIT
// Description: The incoming picture is a shadow caster between three colored lamps and the outgoing picture: its shadow arrives huge, blurred and split into colored fringes, shrinks and sharpens into one crisp gray shadow on the outgoing picture, then front light catches the caster and it lights up in color, bright parts first
// Tags: shadow, light, silhouette, stage, color, blur

// @range(0, 2) How soft and spread the shadow is while far from the screen
uniform float softness; // = 1.0

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float occlusion(vec2 q) {
  vec2 inside = step(vec2(0.0), q) * step(q, vec2(1.0));
  return smoothstep(0.2, 0.85, 1.0 - luma(getToColor(q).rgb)) * inside.x * inside.y;
}

vec4 transition(vec2 uv) {
  float p = progress;
  float d = 1.0 - smoothstep(0.0, 0.62, p);
  float m = 1.0 + 0.9 * d * d;
  float r = 0.04 * d * softness;
  vec2 asp = vec2(1.0 / ratio, 1.0);
  vec3 sh = vec3(0.0);
  for (int k = 0; k < 3; k++) {
    float a = 6.2832 * float(k) / 3.0 + 1.2 * d;
    // a shadow blocking one lamp keeps the color of the other two
    vec2 o = vec2(cos(a), sin(a)) * 0.09 * d * asp;
    vec2 q = (uv - 0.5 - o) / m + 0.5;
    float s = 0.0;
    for (int i = 0; i < 5; i++) {
      float b = 2.4 * float(i) + float(k);
      s += occlusion(q + vec2(cos(b), sin(b)) * r * sqrt(float(i) / 4.0) * asp);
    }
    vec3 lamp = vec3(float(k == 0), float(k == 1), float(k == 2));
    sh += lamp * s / 5.0;
  }
  float strength = smoothstep(0.0, 0.3, p) * (0.85 - 0.25 * d);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec3 screen = a.rgb * (1.0 - strength * sh);
  float f = smoothstep(0.55, 0.95, p);
  float w = clamp(f * 1.6 - (1.0 - luma(b.rgb)) * 0.6 * (1.0 - f), 0.0, 1.0);
  return vec4(mix(screen, b.rgb, w), mix(a.a, b.a, w));
}
