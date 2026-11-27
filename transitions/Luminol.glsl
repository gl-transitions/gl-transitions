// Author: gre
// License: MIT
// Description: The room dims on the outgoing image and mist is sprayed over it in puffs; wherever a puff lands, a ragged blot glows forensic blue with flecks around it and shows the incoming image in that cold light, brightest just after it lands; the blots spread and join while the room lights come back up on the incoming image in full color
// Tags: light, glow, blue, spray, reveal, forensic
// Preview: 0.42

// @range(0.5, 1.2) Time between puffs, relative to the default
uniform float interval; // = 1.0
// @range(0.2, 0.8) How much light the room keeps while it is dimmed
uniform float dim; // = 0.35
// @color Color of the glow (its alpha is its strength)
uniform vec4 glow; // = vec4(0.25, 0.65, 1.0, 1.0)

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

vec4 transition(vec2 uv) {
  vec2 p = uv * vec2(ratio, 1.0);
  vec4 a0 = getFromColor(uv), b0 = getToColor(uv);
  float dark = smoothstep(0.0, 0.3, progress);
  float lights = smoothstep(0.42, 1.0, progress);
  float mist = 0.0, spray = 0.0, fresh = 0.0;
  float rough = vnoise(p * 7.0) * 0.6 + vnoise(p * 19.0) * 0.4;
  for (int i = 0; i < 7; i++) {
    float fi = float(i);
    vec2 c = vec2(hash(vec2(fi, 3.7)) * 0.8 + 0.1, hash(vec2(fi, 11.7)) * 0.7 + 0.15) * vec2(ratio, 1.0);
    float t0 = 0.03 + fi * 0.058 * interval;
    float age = clamp((progress - t0) / 0.45, 0.0, 1.0);
    float R = (0.25 + 0.55 * age) * sqrt(age) * (0.8 + 0.4 * hash(vec2(fi, 1.3)));
    float d = length(p - c) / max(R, 1e-3);
    float on = smoothstep(0.0, 0.04, age);
    float blot = smoothstep(1.0, 0.55, d + 0.45 * (rough - 0.5)) * on;
    mist = max(mist, blot);
    fresh = max(fresh, blot * (1.0 - age) * (1.0 - age));
    spray = max(spray, smoothstep(1.8, 1.05, d) * (1.0 - age) * on);
  }
  float fleck = step(0.975, hash(floor(p * 140.0) + 7.0)) * spray;
  float l = dot(b0.rgb, vec3(0.299, 0.587, 0.114));
  float drops = mist * (0.75 + 0.25 * smoothstep(0.3, 0.9, hash(floor(p * 260.0))));
  vec3 lum = glow.rgb * glow.a * (max((0.12 + 0.8 * l) * drops * (0.6 + 0.6 * fresh), 0.75 * fleck));
  vec3 room = a0.rgb * mix(vec3(1.0), dim * vec3(0.8, 0.95, 1.25), dark);
  room *= 1.0 - 0.8 * mist * dark;
  vec3 col = room + (lum * 1.15 + b0.rgb * 0.15 * mist) * dark;
  col = mix(col, b0.rgb, lights);
  return vec4(min(col, 1.0), mix(a0.a, b0.a, max(lights, mist * dark)));
}
