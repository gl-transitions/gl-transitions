// Author: gre
// License: MIT
// Description: The outgoing image turns into a sunflower of flat color seeds; the angle between them drifts off the golden angle, so they line up into sweeping spirals, then thirteen straight rays, then spirals the other way, while one arm after another takes the colors of the incoming image, and the seeds clear up into it
// Tags: spiral, sunflower, mosaic, flat-color, math
// Preview: 0.4

// @range(300, 1600) Number of seeds
uniform float seeds; // = 900.0
// @range(0.2, 2) How far the angle between two seeds drifts, in degrees
uniform float drift; // = 1.1

const float TAU = 6.2831853;
const float PX = 0.0012;

float hash(float n) {
  float q = fract(n * 0.1031);
  q *= q + 33.33;
  return fract(q * (q + q));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// flat premultiplied color of the seed at s.xy, of index s.z
vec4 paint(vec3 s, vec2 a, float r) {
  float m = smoothstep(0.0, 0.14, progress - 0.26 - 0.34 * fract(mod(s.z, 13.0) * 5.0 / 13.0));
  vec4 acc = vec4(0.0);
  for (int i = 0; i < 4; i++) {
    vec2 o = vec2(mod(float(i), 2.0), floor(float(i) / 2.0)) - 0.5;
    vec2 q = fold((s.xy + o * r) / a + 0.5);
    acc += mix(premultiply(getFromColor(q)), premultiply(getToColor(q)), m);
  }
  return acc * 0.25;
}

vec4 transition(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  vec2 P = (uv - 0.5) * a;
  float r = max(length(P), 1e-4);
  float c = 0.5 * length(a) / sqrt(max(seeds, 1.0));
  float w = 2.0 * progress - 1.0;
  // 5/13 of a turn is 0.954 degree off the golden angle: the sweep is centered on its 13 rays;
  // 3/8 of a turn is taken out, whose multiples are exact, to keep the precision of the angles
  float turn = 0.38196601 - 0.375 + (0.954 + w * mix(0.45, 1.0, abs(w)) * drift) / 360.0;
  float flow = 10.0 * smoothstep(0.0, 1.0, progress);
  float first = ceil(-flow);
  float k = floor(r * r / (c * c) - flow + 0.5);
  // near the center every seed is tried; elsewhere the two around P on each of the 13 arms
  bool core = k < 40.0;
  vec2 ray = P / r;
  // from a seed to the next one of its arm, along the radius and across it
  float bend = fract(13.0 * turn + 0.375) - 0.5;
  vec2 arm = vec2(6.5 * c * c / r, TAU * r * bend);
  float arm2 = max(dot(arm, arm), 1e-9);
  vec3 s1 = vec3(0.0), s2 = vec3(0.0);
  float d1 = 1e9, d2 = 1e9;
  float n = 0.0;
  for (int i = 0; i < 64; i++) {
    if (core) n = first + float(i);
    else {
      if (i > 25) break;
      if (mod(float(i), 2.0) < 0.5) {
        n = k + floor(float(i) * 0.5) - 6.0;
        float an = TAU * fract(fract(n * 0.375) + n * turn);
        vec2 u = vec2(cos(an), sin(an));
        float off = atan(ray.x * u.y - ray.y * u.x, dot(ray, u));
        vec2 v = vec2(c * sqrt(max(n + flow, 0.0)) - r, r * off);
        n += 13.0 * floor(-dot(v, arm) / arm2);
      } else n += 13.0;
    }
    if (n < first) continue;
    float an = TAU * fract(fract(n * 0.375) + n * turn);
    vec3 s = vec3(c * sqrt(n + flow) * vec2(cos(an), sin(an)), n);
    float d = dot(s.xy - P, s.xy - P);
    if (d < d1) {
      d2 = d1;
      s2 = s1;
      d1 = d;
      s1 = s;
    } else if (d < d2) {
      d2 = d;
      s2 = s;
    }
  }
  float gap = max(length(s2.xy - s1.xy), 1e-5);
  float edge = 0.5 * (d2 - d1) / gap;

  float h = hash(s1.z + 100.0);
  float on = smoothstep(0.0, 1.0, (progress - 0.02 - 0.1 * h) / 0.2) * smoothstep(0.0, 1.0, (0.98 - 0.1 * h - progress) / 0.2);
  float disc = smoothstep(-PX, PX, on * 2.2 * c + smoothstep(0.7, 1.0, on) - sqrt(d1) - 2.0 * PX * (1.0 - on));
  disc *= smoothstep(0.0, 0.1, on);
  vec4 seed = mix(paint(s1, a, 0.5 * c), paint(s2, a, 0.5 * c), 0.5 - 0.5 * smoothstep(0.0, PX, edge));
  // the outlines fade out where the seeds get too thin for them
  float line = 0.28 * on * on * smoothstep(0.008, 0.022, min(gap, sqrt(arm2)));
  seed.rgb *= 1.0 - line * (1.0 - smoothstep(0.0, 4.0 * PX, edge));
  vec4 col = mix(premultiply(progress < 0.5 ? getFromColor(uv) : getToColor(uv)), seed, disc);
  return vec4(col.rgb / max(col.a, 1e-5), col.a);
}
