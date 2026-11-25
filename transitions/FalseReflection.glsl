// Author: gre
// License: MIT
// Description: The lower half of the outgoing picture turns to rippling water that reflects the incoming one instead; the whole world then turns upside down around the waterline, the reflection becomes real and the old picture is left shimmering in the water, until the water clears and goes still
// Tags: water, reflection, rotation, surreal, dream

// @range(0, 1) Strength of the ripples on the water
uniform float ripples; // = 0.5
// @range(0, 1) Tint of the water
uniform float tint; // = 0.6
// @param Turn the world clockwise
uniform bool clockwise; // = false

const float PI = 3.14159265;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float near = smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.78, 1.0, p));
  float a = PI * smoothstep(0.2, 0.8, p) * (clockwise ? -1.0 : 1.0);
  float ca = cos(a), sa = sin(a);
  // just enough zoom for the turned pictures to fill the frame, |ca| rounded so that it does not jolt at the quarter turn
  float zoom = sqrt(ca * ca + 0.02 * sa * sa) + abs(sa) * max(ratio, 1.0 / ratio);
  vec2 q = (uv - 0.5) * asp / zoom;
  // the outgoing picture stands upright in s, the incoming one in -s
  vec2 s = vec2(ca * q.x + sa * q.y, ca * q.y - sa * q.x);

  float d = abs(s.y);
  float low = 1.0 - smoothstep(-0.0015, 0.0015, s.y);
  float upright = smoothstep(-0.4, 0.4, ca);
  float wet = near * mix(1.0 - upright, upright, low);
  // ripples look finer toward the far shore
  float lz = log(d + 0.04);
  float w1 = sin(lz * 17.0 + p * 34.0 + 2.5 * sin(s.x * 4.0 + p * 6.0));
  float w2 = sin(lz * 31.0 + p * 47.0 - s.x * 9.0 + 2.0 * sin(s.x * 7.0 - p * 5.0));
  float wave = w1 + 0.6 * w2;
  s += vec2(0.012, 0.02) * wave * wet * ripples * smoothstep(0.0, 0.2, d);

  float field = 0.5 * sin(lz * 9.0 + p * 10.0 + 2.0 * sin(s.x * 3.5 + 1.0)) + 0.35 * sin(lz * 15.0 - p * 9.0 + s.x * 8.0) + 0.15 * w2;
  vec2 x = clamp(vec2(1.0 - p, p) / 0.3, 0.0, 1.0);
  // starts at once, then settles
  vec2 t = x * (1.0 + x - x * x);
  t.x = 1.0 - t.x;
  vec2 shown = smoothstep(-0.25, 0.25, field - 1.26 + 2.52 * t);
  float m = mix(shown.x, shown.y, low);

  vec4 c = mix(pm(getFromColor(mirror(s / asp + 0.5))), pm(getToColor(mirror(0.5 - s / asp))), m);
  c.rgb *= mix(vec3(1.0), vec3(0.66, 0.84, 0.95), wet * tint);
  c.rgb *= 1.0 - 0.5 * wet * tint * exp(-d * 25.0);
  c.rgb += 0.12 * c.a * wet * ripples * smoothstep(0.8, 1.5, wave) * smoothstep(0.0, 0.1, d);
  c.rgb += 0.5 * c.a * ripples * near * exp(-d * 180.0);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
