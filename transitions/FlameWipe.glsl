// Author: gre
// License: MIT
// Description: A wall of flames sweeps across the frame, scorching the outgoing image ahead of it and leaving the incoming image under a fading warm glow
// Tags: fire, flame, burn, wipe, directional

// @param Direction in which the flames sweep across the frame
uniform vec2 direction; // = vec2(0.0, 1.0)
// @range(0, 1) Height of the flames, as a fraction of the frame height
uniform float height; // = 0.4
// @range(0, 1) How much the outgoing image browns and chars ahead of the flames
uniform float scorch; // = 0.7
// @range(0, 1) Strength of the warm glow left on the incoming image
uniform float glow; // = 0.6
// @color Tint of the body of the flames
uniform vec3 color; // = vec3(1.0, 0.4, 0.08)

// width of the scorched band ahead of the flames, and of the glow behind them
const float BAND = 0.45;
// how far off the frame the front starts and ends
const float PAD = 0.3;
// how far the front of the fire wanders around its straight line
const float RAGGED = 0.05;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float noise(vec2 v) {
  vec2 i = floor(v);
  vec2 f = v - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
             mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 v) {
  float sum = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 4; i++) {
    sum += amp * noise(v);
    v = v * 2.03 + vec2(17.3, 9.1);
    amp *= 0.5;
  }
  return sum / 0.9375;
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// color of the fire by its heat: dark red tips, a tinted body, a white-yellow core
vec3 fire(float h) {
  vec3 c = mix(vec3(0.22, 0.01, 0.0), color * color * vec3(1.0, 0.6, 0.4), smoothstep(0.0, 0.3, h));
  c = mix(c, color, smoothstep(0.25, 0.55, h));
  c = mix(c, vec3(1.0, 0.8, 0.35), smoothstep(0.55, 0.8, h));
  return mix(c, vec3(1.0, 0.96, 0.82), smoothstep(0.8, 1.0, h));
}

// width of a flame tongue climbing along an upright line, from its base (s = 0) to its tip
// (s = 1), with a random size
float climbing(float s, float size) {
  return (0.42 + 0.56 * size) * 6.75 * s * (1.0 - s) * (1.0 - s);
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 1e-5 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  // the flames rise upward from the front: over this distance along the direction
  float rise = height * dir.y;
  // half-width of the burning line, and how far it swells
  float w = 0.05 + 0.35 * height;
  float reach = w * (1.75 + 0.6 * abs(dir.x));
  // the front crosses the frame at the same pace whatever the height of the flames
  float extent = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + PAD;
  float e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.3);
  // the fire catches at the start and dies out at the end, the scorch grows in, the glow fades
  float burn = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
  float scorchAmount = scorch * smoothstep(0.0, 0.2, progress);
  float glowAmount = glow * (1.0 - smoothstep(0.75, 1.0, progress));
  // the flames flicker as they go
  float t = progress * 5.0;

  float side = dot(q, vec2(-dir.y, dir.x));
  float front = mix(-extent, extent, e) + RAGGED * (2.0 * noise(vec2(side * 4.0, t * 0.4)) - 1.0);
  // > 0 ahead of the fire, on the outgoing image
  float k = dot(q, dir) - front;

  // heat before the turbulence: the burning line, and the flames rising from it.
  // Billows rising in screen space swell and thin the line; where it stands upright,
  // they are tongues climbing along it, each widest at its base and pointed at its tip
  float billow = noise(vec2(q.x * 3.0 + 5.0, q.y * 2.5 - t * 1.6));
  float y = q.y * 3.0 - t * 1.4;
  float y2 = y + 0.5;
  float climb = max(climbing(fract(y), hash12(vec2(floor(y), 3.0))),
                    climbing(fract(y2), hash12(vec2(floor(y2), 7.0))));
  billow = mix(billow, 0.4 * billow + climb, abs(dir.x));
  float lineWidth = w * (0.25 + 1.5 * billow);
  float line = 1.0 - smoothstep(0.0, lineWidth, abs(k));
  float tongue = 0.0;
  if (abs(rise) > 1e-4) {
    float s = k / rise;
    if (s >= 0.0) tongue = clamp(1.0 - s, 0.0, 1.0);
  }
  float heat = max(line, tongue) * burn;
  float near = 1.0 - smoothstep(0.0, BAND, abs(k));

  // the outgoing image shimmers in the heat ahead of the fire
  vec2 h = q * vec2(9.0, 5.0) + vec2(0.0, -t * 3.0);
  vec2 shimmer = (vec2(noise(h), noise(h + 31.7)) - 0.5) * 0.012 * min(near + heat, 1.0) * burn;
  vec4 a = getFromColor(mirror(uv + shimmer));
  vec4 b = getToColor(uv);

  // the outgoing image browns, then chars close to the flames
  float brown = k > 0.0 ? scorchAmount * near : 0.0;
  float lum = dot(a.rgb, vec3(0.299, 0.587, 0.114));
  a.rgb = mix(a.rgb, lum * vec3(0.9, 0.55, 0.28), brown) * (1.0 - 0.35 * brown) * (1.0 - 0.9 * brown * near * near);
  // the incoming image under a warm glow fading away from the fire
  float g = k < 0.0 ? glowAmount * near : 0.0;
  b.rgb = b.rgb * mix(vec3(1.0), vec3(1.0, 0.6, 0.35), 0.7 * g) + color * 0.4 * g * g;

  // far from the fire, only one of the images shows
  if (k >= max(BAND, max(rise, reach))) return a.a > 0.0 ? a : vec4(0.0);
  if (-k >= max(BAND, max(-rise, reach))) return b.a > 0.0 ? b : vec4(0.0);

  // the two images meet under the burning line (mixed premultiplied)
  float m = smoothstep(-0.5 * w, 0.5 * w, k);
  vec4 c = mix(vec4(b.rgb * b.a, b.a), vec4(a.rgb * a.a, a.a), m);
  if (c.a <= 0.0) return vec4(0.0);
  vec3 col = c.rgb / c.a;

  // turbulence rising in screen space, stretched upward and swaying into pointed tongues
  vec2 f = vec2(q.x * mix(10.0, 6.0, abs(dir.x)), q.y * mix(1.8, 3.2, abs(dir.x)) - t * 2.4);
  float sway = fbm(vec2(q.x * 2.5, q.y * 1.5 - t * 1.2));
  float n = fbm(f + vec2(1.5 * sway - 0.75, 0.0));
  n = clamp(1.7 * n - 0.35, 0.0, 1.0);
  // a continuous hot core hugging the base of the flames
  float core = (1.0 - smoothstep(0.0, 0.35 * lineWidth, abs(k + 0.4 * w * (sway - 0.5)))) * burn * (1.0 - 0.5 * abs(dir.x));
  // under the flames, where they take root, the turbulence calms down into a soft glow
  float root = rise > 0.0 ? clamp(-k / w, 0.0, 1.0) : rise < 0.0 ? clamp(k / w, 0.0, 1.0) : 0.0;
  root *= abs(dir.y);
  float flame = clamp(heat * 0.95 + 0.45 * core * (0.75 + 0.25 * n) - (1.0 - n) * 1.1 * (1.0 - 0.8 * root), 0.0, 1.0);

  // the flames darken what is behind their body and add their light, with a soft halo;
  // the alpha stays the image's
  // crisp around the tongues, soft at their roots
  float body = smoothstep(0.0, 0.08 + 0.5 * root, flame);
  col = col * (1.0 - 0.7 * body) + fire(flame) * (0.45 + 0.65 * flame) * body;
  col += color * 0.25 * heat * heat * (1.0 - body);
  return vec4(clamp(col, 0.0, 1.0), c.a);
}
