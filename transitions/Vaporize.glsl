// Author: gre
// License: MIT
// Description: The outgoing image goes up in smoke: from one side, the picture itself turns to vapour that rises over what is still intact, curls into wisps and pales as it thins out, revealing the incoming image underneath
// Tags: smoke, organic, noise, directional, reveal

// @param Direction the vapour rises toward (the image starts turning to vapour on the opposite side)
uniform vec2 direction; // = vec2(0.0, 1.0)
// @range(0.1, 0.6) How high the vapour rises above the image before it is gone, in frame heights
uniform float rise; // = 0.4
// @range(0, 1) How much the vapour swirls and curls as it rises
uniform float swirl; // = 0.6
// @color Color the vapour pales to as it thins out
uniform vec4 color; // = vec4(0.92, 0.92, 0.94, 1.0)

// raggedness of the line where the image turns to vapour, and the width over which it dissolves
const float RAGGED = 0.09;
const float BAND = 0.12;
// how long the vapour lives, as a part of the transition
const float LIFE = 0.16;
const int TAPS = 6;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
    mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

float fbm(vec2 p) {
  return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.03 + 5.1) + 0.15 * vnoise(p * 4.1 + 9.7);
}

// a swirling flow without sources or sinks: the curl of a noise field
vec2 curl(vec2 p) {
  float e = 0.1;
  float n = vnoise(p);
  float nx = vnoise(p + vec2(e, 0.0));
  float ny = vnoise(p + vec2(0.0, e));
  return vec2(ny - n, n - nx) / e;
}

// where the line is at time t, as a part of its way across: quicker through the margins
// outside the frame, slower across it
float sweep(float t) {
  return t + 0.6 * t * (1.0 - t) * (1.0 - 2.0 * t);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(0.0, 1.0);
  vec2 side = vec2(-dir.y, dir.x);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float along = dot(q, dir);
  float across = dot(q, side);
  float ext = 0.5 * (abs(dir.x) * ratio + abs(dir.y));

  // the line where the image turns to vapour sweeps across the frame, ragged
  float ragged = RAGGED * (2.0 * fbm(q * 2.5 + 1.3) - 1.0);
  float start = -ext - RAGGED;
  float travel = 2.0 * ext + 2.0 * RAGGED + BAND;
  float front = start + travel * sweep(progress) + ragged;

  // under the vapour: the outgoing image where it is still intact, dissolving into the
  // incoming one just behind the line
  float gone = smoothstep(0.0, BAND, front - along);
  vec4 base = mix(getFromColor(uv), getToColor(uv), gone);

  // the vapour above the line: the higher it is, the longer ago it left the image
  float height = max(rise, 0.05) * (0.7 + 0.6 * vnoise(vec2(across * 3.0 + 2.7, 0.5)));
  float age = (along - front) / height;
  float released = progress - age * LIFE;
  if (age <= 0.0 || age >= 1.0 || released <= 0.0) return base;

  // where it came from: the line, back when it was released
  float origin = start + travel * sweep(released) + ragged;
  vec2 org = q - dir * (along - origin);

  // it swirls and curls as it rises
  vec2 sw = curl(org * 3.0 + dir * progress * 1.5) * (swirl * 0.08 * sqrt(age));
  vec2 src = org - sw;

  // and spreads out sideways, blurring as it rises
  vec2 spreadOut = (side * 0.07 + dir * 0.02) * sqrt(age);
  vec4 c = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float t = float(i) / float(TAPS - 1) - 0.5;
    vec4 img = getFromColor(mirror((src + spreadOut * t) / vec2(ratio, 1.0) + 0.5));
    c += vec4(img.rgb * img.a, img.a);
  }
  c = c.a > 0.0 ? vec4(c.rgb / c.a, c.a / float(TAPS)) : vec4(0.0);

  // it breaks up into wisps that rise with it and thin out: thin parts go first
  vec2 wq = (q - 0.6 * sw - dir * (progress * 2.5)) * 4.0;
  float w = fbm(vec2(dot(wq, side), dot(wq, dir) * 0.6) + 2.0);
  float density = smoothstep(1.2 * age - 0.2, 1.2 * age + 0.1, w);
  density *= 1.0 - smoothstep(0.3, 1.0, age);
  // (only the image turns to vapour, not what lies beyond its edge)
  density *= smoothstep(-ext, -ext + 0.05, origin);

  // it pales and loses its colour as it thins
  float pale = smoothstep(0.0, 0.5, age);
  float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  c = mix(c, vec4(mix(vec3(l), color.rgb, 0.7), c.a * color.a), pale * 0.85);
  // the edges of the wisps catch the light
  c.rgb = min(c.rgb + 0.12 * pale * density * (1.0 - density), vec3(1.0));
  // laid over what is under it
  float a = density * c.a;
  float outA = a + base.a * (1.0 - a);
  if (outA <= 0.0) return vec4(0.0);
  return vec4((c.rgb * a + base.rgb * base.a * (1.0 - a)) / outA, outA);
}
