// Author: gre
// License: MIT
// Description: The incoming image is poured in like a paint-bucket fill from two points: the areas of its picture that match the paint's colour flood in almost at once and stop at their outlines, then the bucket's tolerance widens and the other shapes fill in one after another, a light sheen running along the advancing fill
// Tags: fill, flood, regions, paint, structure

// @param First point the fill is poured from
uniform vec2 seedA; // = vec2(0.3, 0.7)
// @param Second point the fill is poured from
uniform vec2 seedB; // = vec2(0.75, 0.25)
// @range(0, 1) How firmly outlines hold the fill back
uniform float hold; // = 0.8

const float W = 0.025;

// a small disc average, so fine texture does not break a flat area into specks
vec3 smoothTo(vec2 uv) {
  vec2 px = vec2(0.008 / ratio, 0.008);
  vec3 c = getToColor(clamp(uv, 0.0, 1.0)).rgb;
  vec2 g = vec2(1.0, 0.0);
  mat2 turn = mat2(0.5, 0.8660254, -0.8660254, 0.5);
  for (int i = 0; i < 6; i++) {
    c += getToColor(clamp(uv + g * px, 0.0, 1.0)).rgb;
    g = turn * g;
  }
  return c / 7.0;
}

float dist(vec2 p, vec2 seed) {
  return length((p - seed) * vec2(ratio, 1.0));
}

float gap(vec2 p) {
  return min(dist(p, seedA), dist(p, seedB));
}

float reach(float d, vec3 here, vec3 paint) {
  // the bucket's tolerance widens with time: a colour unlike the paint's waits at its outline;
  // hue counts more than brightness, so shading inside a shape does not split it
  float lh = dot(here, vec3(1.0)), lp = dot(paint, vec3(1.0));
  float t = 2.5 * length(here / (lh + 0.15) - paint / (lp + 0.15)) + 0.2 * abs(lh - lp);
  t = max(t - 0.05, 0.0);
  float c = min(1.3 * t / (t + 0.3), 1.0);
  float a = 0.85 * (0.4 * d + hold * max(c - 0.4 * d, 0.0)) + 0.15 * d;
  // the most a can reach, with c and d at 1
  return a / (0.49 + 0.51 * hold);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec3 here = smoothTo(uv);
  // the frame corner farthest from both seeds sets the pour's reach
  float far = max(max(gap(vec2(0.0)), gap(vec2(1.0))), max(gap(vec2(0.0, 1.0)), gap(vec2(1.0, 0.0))));
  float dA = dist(uv, seedA) / far, dB = dist(uv, seedB) / far;
  float arrive = min(reach(dA, here, smoothTo(seedA)), reach(dB, here, smoothTo(seedB)));
  // a late, slower pour crosses every outline anyway, so paints unlike the whole picture never stall
  float d = min(min(dA, dB), 1.0);
  arrive = min(arrive, mix(d, 0.5 + 0.5 * d, hold));
  // arrivals bunch in the middle of the range: run the front faster early and slower late
  float front = mix(-W, 1.0 + W, progress + 0.07 * sin(6.2831853 * progress));
  float m = 1.0 - smoothstep(front - W, front, arrive);
  float rim = m * (1.0 - smoothstep(0.0, 0.04, front - arrive)) * (1.0 - progress);
  return mix(a, vec4(mix(b.rgb, vec3(1.0), 0.4 * rim), b.a), m);
}
