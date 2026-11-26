// Author: gre
// License: MIT
// Description: The lights go down and the eye switches to night vision: reds sink to black first while blues stay bright, color drains into a grainy blue-gray where the very center goes dim, the picture changes in the dark, and the incoming one regains its colors as day vision returns
// Tags: light, night, perception, eye, color, grain

// @range(0, 1) How deep into night vision the eye goes
uniform float darkness; // = 0.9
// @range(0, 1) Photon grain of night vision
uniform float grain; // = 0.35

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 seen(vec3 c, float d, float rodOnly, float n) {
  // cones lose long wavelengths first as light falls
  vec3 cone = c * (1.0 - d * vec3(0.95, 0.55, 0.15));
  float rod = max(dot(c, vec3(-0.08, 0.62, 0.46)), 0.0);
  vec3 moon = vec3(0.66, 0.84, 1.2) * rod * (1.0 + n);
  return mix(cone, moon, rodOnly);
}

vec4 transition(vec2 uv) {
  float p = progress;
  float d = darkness * sin(3.14159265 * p);
  float rodOnly = smoothstep(0.35, 0.85, d);
  float m = smoothstep(0.38, 0.62, p);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float frame = floor(p * 48.0);
  float n = grain * rodOnly * (hash(floor((q + 0.5) * 260.0) + frame * 17.0) - 0.5) * 1.6;
  vec4 c = mix(getFromColor(uv), getToColor(uv), m);
  vec3 col = seen(c.rgb, d, rodOnly, n);
  // the fovea has no rods, so what the eye looks straight at fades at night
  float fovea = smoothstep(0.03, 0.22, length(q));
  col *= mix(1.0, mix(0.7, 1.0, fovea), rodOnly);
  col *= 1.0 - 0.2 * d * d;
  return vec4(clamp(col, 0.0, 1.0), c.a);
}
