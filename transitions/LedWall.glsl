// Author: gre
// License: MIT
// Description: The picture zooms into a giant LED screen of round glowing diodes on a dark panel; a refresh wave sweeps across it, each diode flicking with a bright pop as it switches to the incoming image, then the diodes melt back into the plain picture
// Tags: dots, glow, grid, wave

// @range(6, 80) Number of diodes across the shorter side
uniform float cells; // = 24.0
// @range(0, 1) Strength of the glow bleeding from the diodes into the dark panel
uniform float glow; // = 0.6
// @range(0, 1) Brightness of the flash of each diode as it switches
uniform float flash; // = 0.7
// @range(0, 0.5) How much the picture zooms in while it is a screen
uniform float zoom; // = 0.15
// @param Each diode is made of red, green and blue sub-diodes
uniform bool triads; // = false
// @param Direction in which the refresh wave sweeps across the screen
uniform vec2 direction; // = vec2(1.0, 0.0)
// @color Color of the panel between the diodes
uniform vec4 panel; // = vec4(0.02, 0.02, 0.025, 1.0)

// radius of a lit diode, in cells
const float RADIUS = 0.36;
// width of the soft edge of the diodes, in cells
const float EDGE = 0.05;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// folds uv back into 0..1, so the frame stays filled
vec2 mirrored(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

// 1 inside a disc of radius r, with a soft edge
float disc(float d, float r) {
  return 1.0 - smoothstep(r - EDGE, r + EDGE, d);
}

vec4 transition(vec2 uv) {
  // how much the picture is a screen: it resolves into diodes until 0.3, and back from 0.7
  float led = smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
  float z = 1.0 + max(zoom, 0.0) * smoothstep(0.0, 0.45, progress) * (1.0 - smoothstep(0.55, 1.0, progress));
  vec2 p = 0.5 + (uv - 0.5) / z;

  // the grid of diodes, in cells, with a diode at the center of the frame
  vec2 aspect = vec2(ratio, 1.0);
  vec2 toCells = aspect * max(cells, 1.0) / min(ratio, 1.0);
  vec2 q = (p - 0.5) * toCells;
  vec2 id = floor(q + 0.5);
  vec2 local = q - id;
  vec2 side = vec2(local.x < 0.0 ? -1.0 : 1.0, local.y < 0.0 ? -1.0 : 1.0);

  // the refresh wave runs along dir, from 0 to 1 across the frame
  vec2 dir = length(direction) > 1e-4 ? normalize(direction) : vec2(1.0, 0.0);
  float extent = abs(dir.x) * ratio + abs(dir.y);

  vec4 own = vec4(0.0);
  float ownSwitch = 0.0;
  vec4 halo = vec4(0.0);
  float haloWeight = 0.0;
  // this diode and the three nearest ones, whose glow reaches this point
  for (int i = 0; i < 4; i++) {
    // without glow, only this diode matters
    if (i > 0 && glow * led <= 0.0) break;
    vec2 o = vec2(mod(float(i), 2.0), floor(float(i) / 2.0)) * side;
    vec2 c = id + o;
    vec2 cuv = c / toCells + 0.5;
    // where the diode is seen in the frame, so that the wave crosses the visible screen
    float s = clamp(dot((cuv - 0.5) * z * aspect, dir) / extent + 0.5, 0.0, 1.0);
    float when = 0.2 + 0.52 * s + 0.05 * (hash12(c + 71.0) - 0.5);
    float sw = smoothstep(when - 0.012, when + 0.012, progress);
    // the diode blinks off just before it switches, then pops bright
    float x = (progress - when) / 0.018;
    float pop = exp(-x * x) - 0.5 * exp(-(x + 1.6) * (x + 1.6));
    vec2 suv = mirrored(cuv);
    vec4 col = mix(getFromColor(suv), getToColor(suv), sw);
    col.rgb = col.rgb * (1.0 + 1.4 * flash * pop) + 0.2 * flash * max(pop, 0.0);
    if (i == 0) {
      own = col;
      ownSwitch = sw;
    }
    float d = length(local - o);
    float w = 0.9 * glow * exp(-6.0 * max(d - RADIUS, 0.0)) * (1.0 + 0.8 * flash * max(pop, 0.0));
    // the neighbors fade out where the next ones in the other direction take over, so the glow has no seam
    if (o.x != 0.0) w *= smoothstep(0.0, 0.2, abs(local.x));
    if (o.y != 0.0) w *= smoothstep(0.0, 0.2, abs(local.y));
    halo += w * col;
    haloWeight += w;
  }

  // the plain picture, switched along with its diode
  vec4 plain = mix(getFromColor(p), getToColor(p), ownSwitch);
  float d = length(local);
  // the diodes cover their whole cell with the plain picture when led = 0: the dark panel
  // shows up first between them, then they light up with the color of their center
  float r = mix(0.8, RADIUS, smoothstep(0.0, 0.6, led));
  vec4 gap = vec4(panel.rgb, panel.a * own.a);
  if (haloWeight > 0.0) {
    gap = mix(gap, halo / haloWeight, clamp(haloWeight * led, 0.0, 1.0));
  }
  vec4 body = own;
  if (triads) {
    // three sub-diodes on the panel, red at the top, green and blue below
    vec3 sub = vec3(
      disc(length(local - vec2(0.0, 0.15)), 0.2),
      disc(length(local - vec2(-0.13, -0.075)), 0.2),
      disc(length(local - vec2(0.13, -0.075)), 0.2));
    float m = max(sub.r, max(sub.g, sub.b));
    body = vec4(gap.rgb * (1.0 - m) + own.rgb * 1.5 * sub, mix(gap.a, own.a, m));
    // the sub-diodes reach out to 0.4 cells
    r = max(r, 0.45);
  } else {
    // brighter at the core of the diode
    float k = clamp(d / RADIUS, 0.0, 1.0);
    body.rgb *= 0.8 + 0.45 * (1.0 - k * k);
  }
  // the color of the center spreads from it over the diode
  float lit = smoothstep(0.0, 0.8, led);
  body = mix(plain, body, lit * mix(1.0, lit, smoothstep(0.0, 0.7, d)));
  vec4 color = mix(gap, body, disc(d, r));
  return clamp(color, 0.0, 1.0);
}
