// Author: gre
// License: MIT
// Description: Handfuls of bright colored powder are thrown across the outgoing image one after another; each grainy cloud puffs out and dyes the image, and as it thins and drifts off it leaves the incoming image underneath
// Tags: powder, color, festival, cloud, dust, celebration

// @range(0.0, 1.0) How opaque the clouds of powder are
uniform float density; // = 0.85
// @range(0.5, 2.0) Size of the clouds
uniform float cloudSize; // = 1.0

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
             mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 pigment(float i) {
  vec3 c = vec3(1.0, 0.1, 0.55);
  if (i > 0.5) c = vec3(1.0, 0.82, 0.05);
  if (i > 1.5) c = vec3(0.1, 0.75, 0.3);
  if (i > 2.5) c = vec3(0.15, 0.45, 1.0);
  if (i > 3.5) c = vec3(1.0, 0.45, 0.05);
  if (i > 4.5) c = vec3(0.6, 0.2, 0.95);
  return c;
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float n = vnoise(q * 5.0 + progress * vec2(1.5, 2.5)) * 0.65 + vnoise(q * 11.0 - progress * 3.0) * 0.35;
  float cover = 0.0;
  float dust = 0.0;
  vec3 dustCol = vec3(0.0);
  for (int k = 0; k < 6; k++) {
    float i = float(k);
    float tau = (progress - 0.02 - i * 0.105) / 0.4;
    vec2 cell = vec2(mod(i * 2.0, 3.0), mod(i, 2.0));
    vec2 c = vec2((0.18 + 0.32 * cell.x + 0.08 * (hash12(vec2(i, 3.0)) - 0.5)) * ratio, 0.28 + 0.44 * cell.y);
    vec2 dir = normalize(vec2(hash12(vec2(i, 7.0)) - 0.5, 0.35));
    float grow = 1.0 - exp(-5.0 * max(tau, 0.0));
    float r = max(cloudSize * (0.32 + 0.1 * hash12(vec2(i, 9.0))) * max(ratio, 1.0) * grow, 1e-4);
    float d = length(q - c - dir * 0.12 * grow) + (n - 0.5) * 0.5 * r;
    float body = (1.0 - smoothstep(r * 0.35, r, d)) * step(0.0, tau);
    float puff = body * smoothstep(0.0, 0.08, tau) * (1.0 - smoothstep(0.35, 1.0, tau));
    dustCol = mix(dustCol, pigment(i), puff / max(dust + puff, 1e-3));
    dust = max(dust, puff);
    cover = max(cover, body * smoothstep(0.3, 0.6, tau));
  }
  cover = max(cover, smoothstep(0.85, 1.0, progress));
  vec4 base = mix(getFromColor(uv), getToColor(uv), cover);
  float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
  vec3 powder = dustCol * (0.65 + 0.55 * lum) + 0.12 * (n - 0.5);
  float grain = hash12(floor(uv * vec2(ratio, 1.0) * 420.0) + floor(progress * 40.0));
  float a = clamp(dust * density * (0.7 + 0.5 * n) * (0.8 + 0.4 * grain), 0.0, 1.0);
  return vec4(mix(base.rgb, powder, a), base.a);
}
