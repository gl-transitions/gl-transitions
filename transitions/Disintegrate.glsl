// Author: gre
// License: MIT
// Description: The outgoing image crumbles into fine dust from one side, its grains blown away by the wind and fading out, revealing the incoming image underneath
// Tags: particles, dust, wind, directional

// @range(0.005, 0.03) Size of the dust grains, in frame heights
uniform float particleSize; // = 0.007
// @param Direction in which the wind blows the dust
uniform vec2 direction; // = vec2(1.0, -0.15)
// @range(0, 1) How far the dust flies and scatters before it fades out
uniform float spread; // = 0.75

// the most grains, along the wind, that may have flown into a pixel: enough for the
// longest flight (spread = 1) of the smallest grains
const int REACH = 96;
// part of the transition during which a grain flies, from its release to its fade-out
const float LIFE = 0.45;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// smooth value noise, between -1 and 1
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return 2.0 * mix(mix(a, b, f.x), mix(c, d, f.x), f.y) - 1.0;
}

// the grains' sideways drift: a slow swirl across the frame, between -1 and 1
float swirl(vec2 p) {
  return noise(p * 4.0 + 7.1);
}

// when the grain at this center (in frame heights, along and across the wind) is released:
// from the downwind side first, along a ragged front
float release(vec2 center, float halfLength) {
  float x = (center.x + halfLength) / (2.0 * halfLength);
  float front = 1.0 - x + 0.14 * noise(center * 6.0)
    + 0.08 * (hash12(floor(center / particleSize)) - 0.5);
  return clamp((front + 0.12) / 1.24, 0.0, 1.0) * (1.0 - LIFE);
}

vec4 transition(vec2 uv) {
  vec2 d = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 n = vec2(-d.y, d.x);
  // grid of grains aligned with the wind: x along it, y across it, in frame heights
  vec2 fp = (uv - 0.5) * vec2(ratio, 1.0);
  vec2 g = vec2(dot(fp, d), dot(fp, n));
  float halfLength = 0.5 * (ratio * abs(d.x) + abs(d.y));
  float s = particleSize;
  // the longest flight, in frame heights
  float reach = spread * 0.45;

  // this pixel's own grain: once it has left, the incoming image shows through
  vec2 own = (floor(g / s) + 0.5) * s;
  vec4 under = progress > release(own, halfLength) ? getToColor(uv) : getFromColor(uv);
  vec2 grainUV = vec2(0.5);
  float cover = 0.0;
  for (int k = 0; k < REACH; k++) {
    if (float(k - 1) * s > reach) break;
    // the grains that would have flown about k cells along the wind to reach this pixel,
    // drifted sideways by the swirl: the nearest row, and the next nearest one, which
    // catches the grains whose drift differs a little from this guess
    vec2 back = g - vec2(float(k) * s, 0.0);
    back.y -= swirl(back) * 0.3 * float(k) * s;
    vec2 row = back / s;
    float other = fract(row.y) < 0.5 ? -1.0 : 1.0;
    for (int j = 0; j < 2; j++) {
      vec2 cell = floor(row) + vec2(0.0, float(j) * other);
      vec2 center = (cell + 0.5) * s;
      vec2 cuv = (center.x * d + center.y * n) / vec2(ratio, 1.0) + 0.5;
      if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) continue;
      float t = (progress - release(center, halfLength)) / LIFE;
      if (t <= 0.0 || t >= 1.0) continue;
      float r1 = hash12(cell);
      float r2 = hash12(cell + 71.3);
      // the grain speeds up, drifts sideways, shrinks and fades out
      float travel = reach * (0.4 + 0.6 * r2) * t * (0.2 + 0.8 * t);
      // it first fills its cell, then crumbles to a smaller speck, scattered in its cell
      // so that the dust is not a grid
      float crumble = smoothstep(0.0, 0.25, t);
      vec2 jitter = (vec2(r2, hash12(cell + 19.7)) - 0.5) * 0.3 * crumble * s;
      vec2 pos = center + jitter + vec2(travel, swirl(center) * 0.3 * travel);
      vec2 local = (g - pos) / s;
      float size = mix(0.625, 0.3 * (1.0 - 0.5 * t) * (0.6 + 0.4 * r1), crumble);
      float sd = max(abs(local.x), abs(local.y)) - size;
      float a = clamp(0.5 - sd * 4.0, 0.0, 1.0) * (1.0 - smoothstep(0.15, 1.0, t));
      if (a > cover) {
        cover = a;
        grainUV = cuv;
      }
    }
  }
  return mix(under, getFromColor(grainUV), cover);
}
