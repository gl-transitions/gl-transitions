// Author: Paweł Płóciennik
// License: MIT
// Description: A drop falls into the image like into still water: round ripples spread out from where it hits, bending the image with glints on their slopes, the incoming image shows up inside the leading ripple, and the water calms down
// Tags: ripple, water, refraction, circle
// @range(10, 80) Frequency of the ripples: higher makes them closer together
uniform float amplitude; // = 30
// @range(0, 80) Speed of the ripples as they run outward through the spreading rings
uniform float speed; // = 30
// @param Where the drop falls, in texture coordinates
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 0.08) How far the ripples bend the image, in frame heights
uniform float refraction; // = 0.015
// @range(0, 1) Brightness of the glints on the ripples
uniform float highlight; // = 0.5

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// height of the water, from -1 to 1, at a distance s inside the front
float wave(float s, float k, float lambda, float t) {
  // it rises just ahead of the front and dies out a few ripples behind it
  float env = smoothstep(-0.3 * lambda, 0.6 * lambda, s) * exp(-s / (3.5 * lambda));
  // the ripples run out through the train, faster than the train itself spreads
  return env * sin(k * s + speed * t);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  float k = 2.0 * max(amplitude, 1.0);
  float lambda = 6.2831853 / k;
  // measured in square pixels, so the ripples are round
  vec2 q = (uv - center) * vec2(ratio, 1.0);
  float r = length(q);
  vec2 dir = r > 0.0 ? q / r : vec2(0.0);
  // the farthest corner of the frame
  vec2 far = max(center, 1.0 - center) * vec2(ratio, 1.0);
  float R = length(far);

  // the incoming image shows from a little behind the front, with a soft edge
  float edge = 0.35 * lambda;
  float soft = 0.1 * lambda;
  // the front spreads out, slowing down a little, from just before the drop hits until
  // its revealed area is past the farthest corner
  float t = progress;
  float e = mix(t, 1.0 - (1.0 - t) * (1.0 - t), 0.4);
  float front = mix(-0.3 * lambda, R + edge + soft + 0.01, e);
  float s = front - r;

  // the water calms down at the end
  float calm = 1.0 - smoothstep(0.55, 1.0, t);
  calm *= calm;
  // slope of the water along the radius, normalized to at most about 1
  // (one-sided at the very center)
  float d = 0.02 * lambda;
  float r0 = max(r - d, 0.0);
  float slope = calm * (wave(front - r - d, k, lambda, t) - wave(front - r0, k, lambda, t)) / ((r + d - r0) * k);
  vec2 offset = dir * slope * refraction / vec2(ratio, 1.0);

  vec4 ca = getFromColor(mirror(uv - offset));
  vec4 cb = getToColor(mirror(uv - offset));
  float m = smoothstep(edge - soft, edge + soft, s);
  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(ca.rgb * ca.a, ca.a), vec4(cb.rgb * cb.a, cb.a), m);

  // the slopes facing the light glint, the ones facing away darken a little,
  // and the crests are a little brighter than the troughs
  float h = calm * wave(s, k, lambda, t);
  float lit = -dot(dir, normalize(vec2(-0.6, 0.8))) * slope;
  float glint = highlight * (0.2 * h + 0.6 * smoothstep(0.2, 0.9, lit) - 0.3 * smoothstep(0.2, 0.9, -lit));
  c.rgb = clamp(c.rgb + glint * c.a, 0.0, c.a);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
