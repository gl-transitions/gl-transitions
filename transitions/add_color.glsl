// Author: Yoni Maltsman @friendlyspinach
// License: MIT
// Description: Each color channel of the outgoing image is shifted and wraps around into psychedelic bands, while crossfading to the incoming image
// Tags: color, glitch, psychedelic, fade

// @range(-2, 2) Shift of the red channel over the transition
uniform float r_strength; // = 1.0
// @range(-2, 2) Shift of the green channel over the transition
uniform float g_strength; // = 1.0
// @range(-2, 2) Shift of the blue channel over the transition
uniform float b_strength; // = 1.0

vec4 transition (vec2 uv) {
  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);
  vec3 c = from.rgb + vec3(r_strength, g_strength, b_strength)*progress;
  // The wrap flips bright (or, with negative strengths, dark) channels at once: fade it in over the first frames
  from.rgb = mix(from.rgb, mod(c, 1.0), smoothstep(0.0, 0.1, progress));
  return mix(from, to, progress);
}
