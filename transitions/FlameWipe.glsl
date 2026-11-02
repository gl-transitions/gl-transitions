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
const float SCORCH = 0.45;
const float GLOW = 0.45;
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
  vec3 c = mix(vec3(0.3, 0.02, 0.01), color * color * vec3(1.0, 0.7, 0.5), smoothstep(0.0, 0.35, h));
  c = mix(c, color, smoothstep(0.3, 0.6, h));
  c = mix(c, vec3(1.0, 0.82, 0.4), smoothstep(0.6, 0.88, h));
  return mix(c, vec3(1.0, 0.97, 0.88), smoothstep(0.88, 1.0, h));
}

// width of a flame tongue climbing along an upright line, from its base (s = 0) to its tip
// (s = 1), with a random size
float climbing(float s, float size) {
  return (0.6 + 0.8 * size) * smoothstep(0.0, 0.3, s) * (1.0 - s);
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 1e-5 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  // the flames rise upward from the front: over this distance along the direction
  float rise = height * dir.y;
  // half-width of the burning line itself
  float w = 0.05 + 0.35 * height;
  // the front starts and ends far enough off the frame that nothing of the fire shows
  float extent = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  // (the burning line swells up to this half-width)
  float reach = w * (1.75 + 0.6 * abs(dir.x));
  float start = -extent - max(rise, reach) - 1.1 * RAGGED;
  float end = extent + max(-rise, reach) + 1.1 * RAGGED;
  float e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.3);
  // the scorch ahead grows in, the glow behind fades out, before the ends
  float scorchAmount = scorch * smoothstep(0.0, 0.2, progress);
  float glowAmount = glow * (1.0 - smoothstep(0.75, 1.0, progress));
  // the flames flicker as they go
  float t = progress * 5.0;

  float side = dot(q, vec2(-dir.y, dir.x));
  float front = mix(start, end, e) + RAGGED * (2.0 * noise(vec2(side * 4.0, t * 0.4)) - 1.0);
  // > 0 ahead of the fire, on the outgoing image
  float k = dot(q, dir) - front;

  // heat before the turbulence: the burning line, and the flames rising from it
  // billows rising in screen space swell and thin the burning line; where it stands upright,
  // they are tongues climbing along it, each widest at its base and pointed at its tip
  float billow = noise(vec2(q.x * 3.0 + 5.0, q.y * 2.5 - t * 1.6));
  float y = q.y * 3.0 - t * 1.4;
  float y2 = y + 0.5;
  float ta = fract(y);
  float tb = fract(y2);
  float climb = max(climbing(ta, hash12(vec2(floor(y), 3.0))),
                    climbing(tb, hash12(vec2(floor(y2), 7.0))));
  billow = mix(billow, 0.4 * billow + climb, abs(dir.x));
  float lineWidth = w * (0.25 + 1.5 * billow);
  float line = 1.0 - smoothstep(0.0, lineWidth, abs(k));
  float tongue = 0.0;
  if (abs(rise) > 1e-4) {
    float s = k / rise;
    if (s >= 0.0) tongue = clamp(1.0 - s, 0.0, 1.0);
  }
  float heat = max(line, tongue);

  // turbulence rising in screen space, stretched upward and warped into tongues
  vec2 f = vec2(q.x * 8.0, q.y * 2.6 - t * 2.4);
  float warp = fbm(f * 0.7 + vec2(0.0, -t * 0.8));
  float n = fbm(f + vec2(1.4 * warp - 0.7, 0.6 * warp));
  n = clamp(1.6 * n - 0.3, 0.0, 1.0);
  float core = (1.0 - smoothstep(0.0, 0.3 * lineWidth, abs(k))) * n;
  float flame = clamp(heat * 1.05 + 0.25 * core - (1.0 - n) * 0.85, 0.0, 1.0);

  // the images: the outgoing one shimmers in the heat ahead of the fire
  float heatZone = (1.0 - smoothstep(0.0, SCORCH, abs(k))) * smoothstep(0.0, 0.2, progress) + heat;
  vec2 shimmer = vec2(warp - 0.5, n - 0.5) * 0.012 * min(heatZone, 1.0);
  float m = smoothstep(-0.5 * w, 0.5 * w, k);
  vec4 c = vec4(0.0);
  if (m > 0.0) {
    // ahead: the outgoing image browns, then chars close to the flames
    vec4 a = getFromColor(mirror(uv + shimmer));
    float brown = scorchAmount * (1.0 - smoothstep(0.0, SCORCH, k));
    float lum = dot(a.rgb, vec3(0.299, 0.587, 0.114));
    a.rgb = mix(a.rgb, lum * vec3(0.9, 0.55, 0.28), brown) * (1.0 - 0.35 * brown);
    a.rgb *= 1.0 - 0.9 * scorchAmount * (1.0 - smoothstep(0.0, 0.4 * SCORCH, k));
    c = a;
  }
  if (m < 1.0) {
    // behind: the incoming image under a warm glow fading away from the fire
    vec4 b = getToColor(uv);
    float g = glowAmount * (1.0 - smoothstep(0.0, GLOW, -k));
    b.rgb = b.rgb * mix(vec3(1.0), vec3(1.0, 0.6, 0.35), 0.7 * g) + color * 0.4 * g * g;
    c = mix(b, c, m);
  }
  if (c.a <= 0.0) return vec4(0.0);

  // the flames hide what is behind their body and add their light, with a soft halo;
  // the alpha stays the image's
  float body = smoothstep(0.0, 0.3, flame);
  vec3 col = c.rgb * (1.0 - 0.75 * body) + fire(flame) * (0.4 + 0.7 * flame) * body;
  col += color * 0.25 * heat * heat * (1.0 - body);
  return vec4(clamp(col, 0.0, 1.0), c.a);
}
