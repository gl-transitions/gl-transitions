// Author: gre
// License: MIT
// Description: The incoming image flows over the outgoing one like one fluid sliding over another, its front rolling up into a row of curling spirals that wind the two images into each other, tighten as they sweep across the frame and drift sideways, then leave it
// Tags: fluid, wave, swirl, organic, directional, wipe

// @param Direction the front travels toward
uniform vec2 direction; // = vec2(0.0, -1.0)
// @range(0.2, 1.2) Distance between the curls, in frame heights
uniform float spacing; // = 0.55
// @range(0, 12) How many radians the curls wind up while crossing the frame
uniform float winding; // = 9.0
// @range(-1, 1) How far the curls drift sideways while crossing, in frame heights
uniform float drift; // = 0.35

// radius of a curl, relative to the distance between the curls
const float SIZE = 0.47;
// how far the curls are already wound when they enter the frame, in radians
const float START = 1.5;
// how far before the frame the eyes of the curls start, in curl radii
const float ENTER = 0.5;
// share of the transition the curls take to start winding
const float RAMP = 0.15;
// width of the lit lip on the incoming side and of the shadow on the outgoing side, in frame heights
const float LIP = 0.02;
const float SHADOW = 0.035;
// half width of the antialiased interface, in frame heights
const float AA = 0.0015;

// folds coordinates back into the frame, so a curl reaching past the edge never smears its border pixels
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float t = progress;

  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(0.0, -1.0);
  // across the front, so that (side, -dir) keeps the orientation of the frame
  vec2 side = vec2(-dir.y, dir.x);
  vec2 aspect = vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * aspect;
  // half extent of the frame along the travel, in frame heights
  float E = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float S = max(spacing, 0.01);
  float R = SIZE * S;

  // the front sweeps from just before the frame, its curls not wound yet, to fully past it, curls included
  float e = mix(t, t * t * (3.0 - 2.0 * t), 0.3);
  float front = mix(-E - max(ENTER * R, SHADOW + AA), E + R + 0.02, e);
  float slide = drift * t;
  // u across the front, v behind it (on the incoming side)
  float u = dot(p, side) - slide;
  float v = front - dot(p, dir);
  // the curl of this column, centered on the front
  float cu = floor(u / S + 0.5) * S;
  vec2 q = vec2(u - cu, v);
  float r = length(q);
  // away from the front, the images are untouched
  if (v < -max(R, SHADOW)) return getFromColor(uv);
  if (v > max(R, LIP)) return getToColor(uv);

  // each curl winds both images into a spiral: still at its rim, turning most at its eye, tighter as it travels
  float x = clamp(r / R, 0.0, 1.0);
  float s = 1.0 - x * x * (3.0 - 2.0 * x);
  float fall = s * s;
  // the curls start winding as they enter the frame
  float turns = (START + winding * t) * smoothstep(0.0, RAMP, t);
  float a = turns * fall;
  float c = cos(a);
  float sn = sin(a);
  vec2 w = vec2(c * q.x + sn * q.y, c * q.y - sn * q.x);

  vec2 src = mirror(uv + ((w.x - q.x) * side - (w.y - q.y) * dir) / aspect);
  vec4 outgoing = getFromColor(src);
  vec4 incoming = getToColor(src);

  // the interface is where the unwound point crosses the front; its distance on screen comes from the gradient of w.y
  float dfall = -12.0 * s * x * (1.0 - x) / R;
  vec2 grad = vec2(-sn, c) - w.x * turns * dfall * (r > 0.0 ? q / r : vec2(0.0));
  float phi = w.y / max(length(grad), 0.1);
  float m = smoothstep(-AA, AA, phi);

  // a lit lip on the incoming side and a soft shadow on the outgoing side, along the whole interface
  float lip = 1.0 - smoothstep(0.0, LIP, phi);
  float shadow = 1.0 - smoothstep(0.0, SHADOW, -phi);
  incoming.rgb += (1.0 - incoming.rgb) * 0.25 * lip;
  outgoing.rgb *= 1.0 - 0.3 * shadow * shadow;

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 col = mix(vec4(outgoing.rgb * outgoing.a, outgoing.a), vec4(incoming.rgb * incoming.a, incoming.a), m);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
