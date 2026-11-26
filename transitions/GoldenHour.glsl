// Author: gre
// License: MIT
// Description: The sun sinks over the outgoing picture: its light turns golden, then red, and the bright parts cast long shadows that stretch sideways across it; at dusk the picture changes and the sun rises from the other side on the incoming one, its shadows pointing the other way and shortening back to noon
// Tags: light, sun, shadow, sunset, warm, day

// @range(0, 0.5) Longest shadows, in frame heights
uniform float reach; // = 0.3
// @range(0, 1) How dark the dusk gets between the two pictures
uniform float dusk; // = 0.85
// @color Sunlight in the golden hour
uniform vec4 goldColor; // = vec4(1.0, 0.76, 0.48, 1.0)
// @color Sunlight as the sun touches the horizon
uniform vec4 sunsetColor; // = vec4(1.0, 0.42, 0.21, 1.0)
// @color Light of the sky, in the shadows and at dusk
uniform vec4 skyColor; // = vec4(0.55, 0.6, 0.9, 1.0)

float lum(vec2 q, bool to) {
  q = 1.0 - abs(1.0 - abs(q));
  vec3 c = to ? getToColor(q).rgb : getFromColor(q).rgb;
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
  float p = progress;
  bool to = p > 0.5;
  // 0 at noon (both ends), 1 at the horizon (the middle)
  float low = to ? 2.0 - 2.0 * p : 2.0 * p;
  float sunUp = 1.0 - smoothstep(0.8, 0.98, low);
  float slope = 5.0 * (1.0 - low) * (1.0 - low) + 0.03;
  // the sun sets on one side and rises on the other, so the shadows keep turning the same way
  vec2 dir = normalize(vec2(to ? -1.0 : 1.0, 0.35)) * vec2(1.0 / ratio, 1.0);
  float h0 = lum(uv, to);
  float occ = 0.0;
  for (int i = 1; i <= 14; i++) {
    float t = reach * float(i) / 14.0;
    // texture-level bumps cast nothing; far occluders cast softer edges
    occ = max(occ, (lum(uv + dir * t, to) - h0 - 0.1 - t * slope) / (0.3 + 4.0 * t));
  }
  float shade = smoothstep(0.0, 0.12, occ) * smoothstep(0.0, 0.25, low);
  vec4 c = mix(getFromColor(uv), getToColor(uv), smoothstep(0.44, 0.56, p));
  vec3 sun = mix(vec3(1.0), mix(1.25 * goldColor.rgb, 1.2 * sunsetColor.rgb, smoothstep(0.55, 0.95, low)), smoothstep(0.0, 0.5, low));
  vec3 sky = mix(vec3(1.0), skyColor.rgb, smoothstep(0.1, 0.9, low));
  vec3 light = mix(sky * mix(1.0, 0.6, smoothstep(0.0, 0.5, low)), sun, (1.0 - shade) * sunUp);
  light *= 1.0 - 0.4 * dusk * smoothstep(0.85, 1.0, low);
  return vec4(min(c.rgb * light, vec3(1.0)), c.a);
}
