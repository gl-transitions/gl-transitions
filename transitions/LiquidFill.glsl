// Author: gre
// License: MIT
// Description: The incoming image rises over the outgoing one like liquid filling a glass, its surface sloshing in waves, lit by a bright meniscus line, bending the image just below it, with a few bubbles rising through it
// Tags: liquid, water, wave, directional, reveal

// @param Direction the liquid rises toward
uniform vec2 direction; // = vec2(0.0, 1.0)
// @range(0, 0.3) Height of the waves on the surface, in frame heights
uniform float amplitude; // = 0.06
// @range(0.5, 6) Number of waves across the frame
uniform float waves; // = 1.5
// @color Color of the bright line along the surface and the rims of the bubbles (its alpha is its strength)
uniform vec4 highlight; // = vec4(1.0, 1.0, 1.0, 0.8)
// @range(0, 0.1) How much the incoming image is bent just below the surface
uniform float refraction; // = 0.03
// @range(0, 1) How many bubbles rise through the liquid
uniform float bubbles; // = 0.5

const float PI = 3.141592653589793;
// half width of the antialiased edges, in frame heights
const float AA = 0.0015;
// width of the meniscus line, in frame heights
const float LINE = 0.006;
// size of the cells the bubbles are scattered in, in frame heights
const float CELL = 0.08;

float hash (vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// height of the surface above its mean level at x (across the frame, from -1 to 1), between -1 and 1:
// a slosh from side to side and a smaller wave running along it
float surface (float x, float t) {
  float k = PI * max(waves, 0.01);
  return 0.6 * sin(k * x + 0.5 * PI) * cos(2.0 * PI * 1.3 * t)
       + 0.4 * sin(1.7 * k * x - 9.0 * t + 1.3);
}

vec4 transition (vec2 uv) {
  vec4 a = getFromColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return getToColor(uv);

  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(0.0, 1.0);
  vec2 across = vec2(-dir.y, dir.x);
  // measured in square pixels, so the waves and bubbles are not stretched
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  // half extents of the frame along the direction and across it
  float e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float w = 0.5 * (abs(dir.y) * ratio + abs(dir.x));
  float d = dot(p, dir);
  float x = dot(p, across);
  float t = progress;
  // the liquid moves most in the middle of the transition and settles at the ends
  float stir = sin(PI * t);
  float amp = max(amplitude, 0.0) * (0.35 + 0.65 * stir);
  // the surface starts fully below the frame and ends fully above it, waves and meniscus included
  float margin = max(amplitude, 0.0) + 2.0 * LINE + AA;
  float mean = mix(-e - margin, e + margin, mix(t, t * t * (3.0 - 2.0 * t), 0.5));
  float level = mean + amp * surface(x / w, t);
  // > 0 below the surface, in the liquid
  float depth = level - d;
  float m = smoothstep(-AA, AA, depth);

  // the incoming image is bent by the waves just below the surface, less and less deeper down
  float bend = refraction * stir * exp(-max(depth, 0.0) / 0.06);
  vec2 offset = bend * (dir * sin(18.0 * x - 7.0 * t) + across * cos(13.0 * x + 5.0 * t));
  vec4 b = getToColor(clamp(uv + offset / vec2(ratio, 1.0), 0.0, 1.0));

  // bubbles rise in columns through the liquid, carried up with it and rising faster still
  float glow = 0.0;
  float rise = mean + 0.5 * t;
  vec2 bq = vec2(x, d - rise) / CELL;
  vec2 cell = floor(bq);
  float hs = hash(cell + 7.1);
  float r = (0.12 + 0.18 * hash(cell + 3.7)) * stir;
  float px = AA / CELL;
  if (hs < bubbles * 0.6 && r > px) {
    // placed so that it stays inside its cell, wobble and soft edge included
    vec2 c = cell + 0.5 + (0.42 - r - px) * (vec2(hash(cell + 1.3), hash(cell + 9.4)) * 2.0 - 1.0);
    // a slight wobble as it rises
    c.x += 0.08 * sin(6.0 * t + 6.28 * hs);
    float dist = length(bq - c);
    // its rim, and a small glint near its top
    float rim = smoothstep(0.7 * r - px, 0.7 * r + px, dist) * (1.0 - smoothstep(r - px, r + px, dist));
    float glint = 1.0 - smoothstep(0.25 * r - px, 0.25 * r + px, length(bq - c - 0.45 * r * vec2(-0.7, 0.7)));
    // only in the liquid, and fading out as it nears the surface
    glow = max(rim * 0.6, glint) * smoothstep(0.0, 0.05, depth) * stir;
  }
  // the meniscus: a bright line along the surface, on the liquid side
  float line = 1.0 - smoothstep(LINE - AA, LINE + AA, abs(depth - LINE));
  line += 0.35 * stir * exp(-max(depth, 0.0) / 0.03) * m;
  float light = highlight.a * clamp(max(line, glow), 0.0, 1.0) * (0.4 + 0.6 * stir);
  b.rgb = mix(b.rgb, highlight.rgb, light);

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
