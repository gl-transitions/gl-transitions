// Author: gre
// License: MIT
// Description: The outgoing image collapses into a glowing line and a dot, like an old TV turned off, then the incoming image powers on from the dot
// Tags: retro, vertical, flash

// @color Color of the switched-off screen
uniform vec4 color; // = vec4(0.0, 0.0, 0.0, 1.0)
// @range(0, 2) Strength of the glow around the line and the dot
uniform float glow; // = 1.0

vec4 getColor(vec2 uv, bool isFrom) {
  return isFrom ? getFromColor(uv) : getToColor(uv);
}

// The screen at a time t of its power-off: 0 is the full image, 1 is off
vec4 screen(vec2 uv, float t, bool isFrom) {
  float collapse = smoothstep(0.0, 0.4, t); // the image squeezes into a line
  float shrink = smoothstep(0.3, 0.65, t); // the line shrinks into a dot
  float fade = 0.4 * smoothstep(0.75, 1.0, t); // the dot dims
  float radius = 0.01 * (1.0 - fade);
  // half size of the picture, in height units (x is scaled by ratio)
  vec2 size = vec2(mix(0.5 * ratio, radius, shrink), mix(0.5, radius, collapse));
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  vec2 q = clamp(0.5 + 0.5 * p / size, 0.0, 1.0);
  vec4 c = getColor(q, isFrom);
  // the squeezed picture gets brighter and burns to white
  float white = smoothstep(0.4, 1.0, collapse);
  vec4 light = vec4(mix(min(c.rgb * (1.0 + 2.0 * collapse), 1.0), vec3(1.0), white), c.a);
  // soft edges, outside the picture so that t = 0 is the exact image
  vec2 d = abs(p) - size;
  float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
  float inside = clamp(1.0 - dist / 0.004, 0.0, 1.0);
  // a glow around the line, tinted by the center of the picture, then warm white around the dot
  vec4 mid = getColor(vec2(0.5), isFrom);
  vec4 halo = vec4(mix(mix(mid.rgb, vec3(1.0), 0.7), vec3(1.0, 0.92, 0.8), shrink), mid.a);
  float h = 1.0 - exp(-2.0 * glow * white * exp(-max(dist, 0.0) / (0.02 + 0.04 * shrink)));
  vec4 col = mix(color, halo, h * (1.0 - fade));
  return mix(col, light, inside * (1.0 - fade));
}

vec4 transition(vec2 uv) {
  if (progress < 0.5) {
    return screen(uv, 2.0 * progress, true);
  }
  return screen(uv, 2.0 - 2.0 * progress, false);
}
