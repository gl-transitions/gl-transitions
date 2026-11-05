// Author: gre
// License: MIT
// Description: The camera jumps to light speed: star streaks shoot out from the center and stretch longer and longer while the outgoing image is pulled into a radial smear, then after a flash the incoming image emerges from the center as the streaks shrink back
// Tags: zoom, radial, light, motion-blur, space

// @param Point the camera flies toward, from (0, 0) at the bottom left to (1, 1) at the top right
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(20, 400) Number of star streaks around the center
uniform float streaks; // = 160.0
// @color Color of the streaks and of the flash, added as light
uniform vec4 streakColor; // = vec4(0.78, 0.88, 1.0, 1.0)
// @range(0, 1) Length of the streaks and of the radial smear
uniform float strength; // = 0.6
// @range(0, 1) Brightness of the flash at the peak of the jump
uniform float flash; // = 0.5

const float PI = 3.141592653589793;
const int TAPS = 12;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// one layer of stars: one per angular cell, flying outward and stretched along its ray
float stars(float a, float r, float n, float layer, float travel, float speed, float reach) {
  float cell = floor(a * n);
  float h1 = hash(vec2(cell, layer));
  float h2 = hash(vec2(cell, layer + 17.0));
  float h3 = hash(vec2(cell, layer + 31.0));
  // where the star is in its flight, from near the center to past the corners,
  // speeding up as it comes closer
  float life = fract(h1 + travel * (0.6 + 0.8 * h2));
  float head = reach * (0.05 + 1.05 * pow(life, 1.4));
  // the streak is the path of the star during the exposure: longer when the camera is faster
  float tail = head * (1.0 - min(0.9, speed * (0.15 + 0.5 * h3)));
  float along = clamp((r - tail) / max(head - tail, 1e-4), 0.0, 1.0);
  float inside = step(tail, r) * (1.0 - smoothstep(head - 0.006, head, r));
  // brightest at the head, fading toward the tail
  float profile = inside * along * along;
  // thin across the ray, a bit wider away from the center, with a faint halo,
  // faded out before the edges of the cell so that no seam shows between cells
  float f = fract(a * n);
  float cellWidth = 2.0 * PI * r / n;
  float offset = 0.3 + 0.4 * h3;
  float across = (f - offset) * cellWidth;
  float width = min(0.0014 + 0.002 * r / reach, 0.15 * cellWidth);
  float x = across * across / (width * width);
  float line = (exp(-x) + 0.25 * exp(-x / 9.0)) * smoothstep(0.0, 0.2, min(f, 1.0 - f));
  // fade in from far away, out past the frame, and only some cells hold a star
  float fade = smoothstep(0.0, 0.2, life) * (1.0 - smoothstep(0.9, 1.0, life));
  return profile * line * fade * (0.4 + 0.6 * h2) * step(0.25, hash(vec2(cell, layer + 43.0)));
}

// an image pulled into a radial smear toward the center: scaled by k, blurred over a fraction b
vec4 smear(vec2 uv, float k, float b, float jitter, bool incoming) {
  if (b <= 0.0 && k >= 1.0) {
    vec4 c = incoming ? getToColor(uv) : getFromColor(uv);
    return vec4(c.rgb * c.a, c.a);
  }
  vec4 sum = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float s = k * (1.0 - b * (float(i) + jitter) / float(TAPS));
    vec2 q = center + (uv - center) * s;
    vec4 c = incoming ? getToColor(q) : getFromColor(q);
    sum += vec4(c.rgb * c.a, c.a);
  }
  return sum / float(TAPS);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 aspect = vec2(ratio, 1.0);
  vec2 d = (uv - center) * aspect;
  float r = length(d);
  // (nudged off zero, where atan is undefined)
  float a = atan(d.y, d.x + 1e-6) / (2.0 * PI) + 0.5;
  // distance from the center to the farthest corner
  vec2 far = max(center, 1.0 - center) * aspect;
  float reach = length(far);

  // the camera speeds up to the jump, at the middle, then slows down
  float speed = sin(PI * p);
  speed *= speed;
  float travel = 3.0 * (p - sin(2.0 * PI * p) / (2.0 * PI));
  float jitter = hash(floor(uv * aspect * 997.0));

  // the outgoing image is pulled forward into the smear; the incoming one arrives
  // magnified and smeared, and settles
  float goOut = smoothstep(0.0, 0.55, p);
  float goIn = 1.0 - smoothstep(0.45, 1.0, p);
  // the incoming image emerges from the center and spreads out to the corners
  float soft = 0.35 * reach;
  float edge = mix(-soft, reach + soft, smoothstep(0.42, 0.78, p));
  float m = 1.0 - smoothstep(edge - soft, edge, r);
  vec4 before = vec4(0.0);
  vec4 after = vec4(0.0);
  if (m < 1.0) before = smear(uv, 1.0 - 0.3 * strength * goOut * goOut, 0.6 * strength * goOut, jitter, false);
  if (m > 0.0) after = smear(uv, 1.0 - 0.3 * strength * goIn * goIn, 0.6 * strength * goIn, jitter, true);
  vec4 c = mix(before, after, m);
  // darker while in the jump, so that the streaks stand out, and brighter soon after it
  // so the incoming image comes out clear
  float dark = p < 0.5 ? speed : speed * speed * speed;
  c.rgb *= 1.0 - 0.65 * (0.5 + 0.5 * strength) * dark;

  // the streaks: two layers of stars, their length growing with the speed
  float n = max(floor(streaks), 1.0);
  float len = speed * (0.5 + 1.5 * strength);
  float s = stars(a, r, n, 1.0, travel, len, reach);
  s += stars(fract(a + 0.37), r, max(floor(n * 0.71), 1.0), 2.0, travel * 1.3, len, reach);
  // the flash, brightest at the center, where the incoming image emerges
  float core = r / (0.35 * reach);
  float peak = (p - 0.5) * 9.0;
  float glow = flash * exp(-peak * peak) * speed * (0.35 + 0.9 * exp(-core * core));
  vec3 light = streakColor.rgb * streakColor.a * (2.2 * s * speed + glow);
  // light is added to the image, but adds no opacity
  return c.a > 0.0 ? vec4(clamp(c.rgb / c.a + light, 0.0, 1.0), c.a) : vec4(0.0);
}
