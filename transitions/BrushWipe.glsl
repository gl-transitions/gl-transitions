// Author: gre
// License: MIT
// Description: A few broad brush strokes sweep across the frame in turn, back and forth, painting in the incoming image with streaky bristle edges and dry, ragged ends
// Tags: wipe, paint, brush, organic

// @range(1, 8, 1) Number of brush strokes needed to cover the frame
uniform float strokes; // = 4.0
// @range(-45, 45) Angle of the strokes, in degrees
uniform float angle; // = -7.0
// @range(0, 1) How rough the bristles make the edges and ends of the strokes
uniform float roughness; // = 0.6
// @range(0, 1) How much the strokes wave along their way
uniform float waviness; // = 0.5

const float PI = 3.141592653589793;

float hash (vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// value noise, smooth along both axes
float vnoise (vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// bristle streaks: fine across the stroke (t), long along it (u)
float bristles (float t, float u, float seed) {
  return 0.6 * vnoise(vec2(t * 26.0 + seed, u * 1.3 + seed)) + 0.4 * vnoise(vec2(t * 8.0 - seed, u * 0.7));
}

// one stroke: k its index, t the position across it (-1..1 is its core), u along it
// returns (coverage, wet streak shading)
vec2 stroke (float k, float t, float u, float U, float n, float h) {
  float dir = mod(k, 2.0) < 0.5 ? 1.0 : -1.0;
  float x = u * dir;
  float dur = min(1.0, 1.8 / (n + 0.8));
  float start = n > 1.0 ? k * (1.0 - dur) / (n - 1.0) : 0.0;
  float s = clamp((progress - start) / dur, 0.0, 1.0);
  s = mix(s, s * s * (3.0 - 2.0 * s), 0.7);
  float r = roughness;
  float lag = (0.15 + 0.6 * r) * h; // how far the longest bristles run ahead of the shortest
  float dry = (0.1 + 0.9 * r) * h; // length of the streaky, dry trail behind the head of the stroke
  // at the end even the shortest bristles, at the rounded corners, are past the far edge with their dry trail
  float head = mix(-U, U + lag + 0.3 * h + 1.15 * dry + 0.01, s);
  float b = bristles(t, k * 3.7, k * 17.0);
  float front = head - lag * (1.0 - b) - 0.3 * h * t * t; // a rounded, ragged head
  float streak = bristles(t * 1.7, x * 2.0 / h, k * 5.0 + 9.0);
  float along = clamp(((front - x) / (dry + 0.001) - 0.1 - 0.8 * streak) * 6.0, 0.0, 1.0);
  float fringe = 0.1 + 0.7 * r;
  float e = (abs(t) - 1.0) / fringe; // < 0 in the core of the stroke
  float reach = 0.5 + 0.5 * vnoise(vec2(x * 2.5 / h, k * 7.0 + (t > 0.0 ? 3.0 : 0.0))); // the edge wanders
  float hair = clamp(bristles(t * 1.4, x * 3.0 / h, k * 11.0 + 3.0) * 2.0 - 0.5, 0.0, 1.0);
  float side = clamp((reach * hair - e) * 12.0 + 1.0, 0.0, 1.0);
  float cover = along * side;
  float wet = (1.0 - clamp((progress - start - dur) / 0.25, 0.0, 1.0)) * min(1.0, (1.0 - progress) * 6.0);
  return vec2(cover, cover * wet * (bristles(t * 2.0, x * 2.0 / h, k) - 0.5));
}

vec4 transition (vec2 uv) {
  float a = angle * PI / 180.0;
  float c = cos(a);
  float sn = sin(a);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float u = c * q.x + sn * q.y; // along the strokes
  float v = -sn * q.x + c * q.y; // across them
  float U = 0.5 * (abs(c) * ratio + abs(sn));
  float V = 0.5 * (abs(sn) * ratio + abs(c));
  float n = max(1.0, floor(strokes + 0.5));
  float h = 2.0 * V / n; // height of a stroke
  // waves shared by the neighbouring strokes so that they always tile the frame
  float A = 0.12 * waviness * h;
  float w = v + A * sin(u * 5.0 / U + v * 2.0 / h + 1.3) + 0.5 * A * sin(u * 11.0 / U - v * 3.0 / h);
  float y = (V + 1.5 * A - w) / (2.0 * V + 3.0 * A) * n; // strokes go from top to bottom
  float hh = (2.0 * V + 3.0 * A) / n;
  float k = clamp(floor(y), 0.0, n - 1.0);
  float cover = 0.0;
  float shade = 0.0;
  for (int i = -1; i <= 1; i++) {
    float j = k + float(i);
    if (j >= 0.0 && j <= n - 1.0) {
      vec2 s = stroke(j, (y - j - 0.5) * 2.0, u, U, n, hh);
      cover = max(cover, s.x);
      shade = mix(shade, s.y, s.x); // the latest stroke is on top
    }
  }
  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);
  to.rgb = min(to.rgb * (1.0 + 0.2 * shade), 1.0);
  return mix(from, to, cover);
}
