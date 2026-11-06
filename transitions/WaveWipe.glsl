// Author: gre
// License: MIT
// Description: A breaking wave crashes across the frame, its lip curling over in front of its face and throwing foam and spray ahead, its shadow darkening the outgoing image; the incoming image is left behind it, tinted and bent by the water, clearing as the wave passes
// Tags: water, wave, ocean, foam, directional, reveal

// @param Direction the wave travels toward
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0.1, 0.45) Size of the curling lip, in wave heights: how far it overhangs ahead of the face
uniform float curl; // = 0.3
// @range(0, 1) Amount of foam on the crest and spray thrown ahead of it
uniform float foam; // = 0.6
// @range(0, 0.1) How much the water bends the incoming image behind the wave
uniform float refraction; // = 0.04
// @color Color of the water tinting the incoming image behind the wave (its alpha is its strength)
uniform vec4 water; // = vec4(0.05, 0.36, 0.46, 0.75)
// @color Color of the foam and spray (its alpha is its strength)
uniform vec4 foamColor; // = vec4(1.0, 1.0, 1.0, 1.0)

const float PI = 3.141592653589793;
// half width of the antialiased edges, in wave heights
const float AA = 0.002;
// how far the base of the face trails behind its top, in wave heights
const float TRAIL = 0.35;
// how far behind the face the water still tints the incoming image, in wave heights
const float BAND = 0.4;
// how far ahead of the lip the spray reaches, in wave heights
const float REACH = 0.25;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float vnoise(vec2 v) {
  vec2 i = floor(v);
  vec2 f = fract(v);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
    mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// folds coordinates back into the frame, so a displaced image never shows its clamped edges
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// droplets scattered in cells, one per cell at most, kept inside their cell
float droplets(vec2 q, float cell, float density, float seed) {
  vec2 g = q / cell;
  vec2 id = floor(g);
  if (hash12(id + seed) >= density) return 0.0;
  float r = 0.1 + 0.2 * hash12(id + seed + 4.7);
  vec2 c = id + 0.5 + (0.45 - r) * (vec2(hash12(id + seed + 1.3), hash12(id + seed + 8.1)) * 2.0 - 1.0);
  float px = AA / cell;
  return 1.0 - smoothstep(r - px, r + px, length(g - c));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float t = progress;

  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  // the crest points up the frame, or to the left when the wave travels straight up or down
  vec2 up = vec2(-dir.y, dir.x);
  if (up.y < 0.0 || (up.y == 0.0 && up.x > 0.0)) up = -up;
  // half extents of the frame along the travel and across it, in frame heights
  float e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float w = 0.5 * (abs(up.x) * ratio + abs(up.y));
  // in wave heights: u along the travel, v from the trough (0) to the crest (1)
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0) / (2.0 * w);
  vec2 q = vec2(dot(p, dir), dot(p, up) + 0.5);
  float E = e / (2.0 * w);

  float R = max(curl, 0.01);
  // radius of the hollow at the back of the curl, where it meets the face
  float Rb = 0.5 * R;
  // the lip pitches forward, then curls further down as the wave travels
  float tipAngle = PI * (0.08 - 0.5 * smoothstep(0.0, 0.85, t));
  // the wave sweeps from fully ahead of the frame, spray included, to fully past it, tinted water included
  float travel = mix(t, t * t * (3.0 - 2.0 * t), 0.25);
  vec2 C = vec2(mix(-E - R - REACH, E + Rb + TRAIL + BAND, travel), 1.02 - R);

  // polar coordinates around the center of the curl
  vec2 d = q - C;
  // atan is undefined at the very center
  if (d.x == 0.0) d.x = 1e-6;
  float r = length(d);
  float ang = atan(d.y, d.x);
  // the inner surface of the curl spirals in from the tip of the lip (zero thickness) to the back of the hollow
  float k = clamp((ang - tipAngle) / (PI - tipAngle), 0.0, 1.0);
  float rIn = R - (R - Rb) * (1.0 - (1.0 - k) * (1.0 - k));
  bool curled = ang >= tipAngle;
  // the face below the curl: vertical where it meets the hollow, its base trailing behind
  float s = 1.0 - clamp(q.y / C.y, 0.0, 1.0);
  float face = C.x - Rb - TRAIL * s * s;
  float behind = face - q.x; // > 0 behind the face

  float wet;
  if (curled) {
    wet = smoothstep(-AA, AA, r - rIn) * (ang > 0.5 * PI ? 1.0 : 1.0 - smoothstep(-AA, AA, r - R));
  } else {
    wet = smoothstep(-AA, AA, behind);
  }
  // the lip: the curl in front of the top of the wave
  float lip = curled ? 1.0 - smoothstep(0.5 * PI - 0.3, 0.5 * PI + 0.5, ang) : 0.0;

  float n = vnoise(q * vec2(14.0, 10.0) + vec2(-9.0 * t, 3.0 * t));

  // outgoing image, darkened in the hollow and in the shadow of the overhang just ahead of it
  vec4 a = getFromColor(uv);
  float gap = max(min(r - R, -behind), 0.0);
  float shade = 0.55 * exp(-gap / 0.1) * (1.0 - smoothstep(0.0, REACH, gap)) * smoothstep(0.0, 0.6, q.y) * (1.0 - smoothstep(C.y + 0.2 * R, C.y + 1.1 * R, q.y));
  shade += 0.25 * (1.0 - smoothstep(0.0, R, r));
  a.rgb *= 1.0 - shade;
  // spray thrown ahead of the crest, drifting forward and falling, and a mist along it
  float fwd = max(r - R, 0.0);
  float zone = smoothstep(tipAngle - 0.4, tipAngle + 0.2, ang) * (1.0 - smoothstep(0.0, REACH, fwd)) * step(0.0, r - R);
  // stretched along the throw, so the droplets streak forward
  vec2 sq = (d - t * vec2(0.5, -0.25)) * vec2(0.55, 1.0);
  float thin = exp(-fwd / 0.12);
  float spray = droplets(sq, 0.02, foam * thin, 1.0) + 0.6 * droplets(sq * 1.6 + 3.1, 0.02, foam * thin, 7.0);
  // the mist hugs the outside of the lip only
  float mist = foam * n * n * exp(-fwd / 0.06) * (1.0 - smoothstep(0.0, REACH, fwd)) * smoothstep(-AA, AA, r - R) * smoothstep(tipAngle, tipAngle + 0.3, ang);
  a.rgb = mix(a.rgb, foamColor.rgb, foamColor.a * clamp(spray * zone + mist, 0.0, 1.0));

  // incoming image behind the face, bent and tinted by the water, clearing further behind
  float band = max(1.0 - smoothstep(0.05, BAND, behind), lip);
  float bend = refraction * band * band;
  vec2 off = bend * (dir * sin(17.0 * q.y + 2.0 * sin(9.0 * q.x) - 6.0 * t) + up * cos(13.0 * q.x - 5.0 * t));
  vec4 b = getToColor(mirror(uv + off * 2.0 * w / vec2(ratio, 1.0)));
  float luma = dot(b.rgb, vec3(0.299, 0.587, 0.114));
  // lit near the top of the face and through the thin lip, darker on the underside of the lip
  vec3 tinted = water.rgb * (0.4 + 0.9 * luma) * (1.0 + 0.6 * q.y);
  tinted += 0.18 * lip * (1.0 - k) * vec3(0.5, 1.0, 0.9);
  tinted *= 1.0 - 0.35 * lip * (1.0 - smoothstep(0.0, 0.06, r - rIn));
  // a bright line along the surface of the face, fading up into the hollow
  tinted += 0.35 * (curled ? k * (1.0 - smoothstep(0.0, 0.015, r - rIn)) : 1.0 - smoothstep(0.0, 0.015, behind)) * vec3(0.7, 0.95, 1.0);
  b.rgb = mix(b.rgb, tinted, water.a * band);

  // foam: whitewater along the outer edge of the lip, and churning at the base of the face
  float crest = curled ? (1.0 - smoothstep(0.01, 0.02 + 0.12 * n, abs(R - r))) * smoothstep(tipAngle, tipAngle + 0.4, ang) * (1.0 - smoothstep(0.5 * PI + 0.2, 0.5 * PI + 0.8, ang)) : 0.0;
  float churn = (1.0 - smoothstep(0.0, 0.15 + 0.1 * n, q.y)) * (1.0 - smoothstep(0.0, 0.3, abs(behind))) * smoothstep(0.3, 0.7, n);
  b.rgb = mix(b.rgb, foamColor.rgb, foamColor.a * clamp(foam * 1.5 * (crest + churn), 0.0, 1.0));

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), wet);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
