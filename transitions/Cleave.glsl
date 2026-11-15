// Author: gre
// License: MIT
// Description: The incoming image is driven into the outgoing one like a wedge into a log: a crack runs ahead of its point, the two halves are shoved aside and bunch up against its sides, then fall apart out of the frame
// Tags: split, push, wedge, shadow

// @param Direction the wedge is driven in, snapped to the nearest of the four edge-to-edge directions
uniform vec2 direction; // = vec2(0.0, -1.0)
// @range(5, 40) Half angle of the wedge, in degrees
uniform float opening; // = 18.0
// @range(0, 1) How much the halves bunch up against the wedge instead of sliding away rigidly
uniform float squash; // = 0.6
// @range(0, 1) Strength of the ridge and shadow shading along the split
uniform float shading; // = 0.7

const float EDGE = 0.0025;
// how far into each half the bunching reaches, in frame heights
const float FALLOFF = 0.11;

float zigzag (float v) {
  return abs(fract(v) - 0.5) * 4.0 - 1.0;
}

vec4 transition (vec2 uv) {
  float p = progress;
  vec2 S = vec2(ratio, 1.0);
  // snapped to an axis so that the wedge runs from one edge of the frame to the opposite one
  vec2 D = abs(direction.x) > abs(direction.y) ? vec2(sign(direction.x), 0.0) : vec2(0.0, direction.y > 0.0 ? 1.0 : -1.0);
  vec2 N = vec2(-D.y, D.x);
  vec2 q = (uv - 0.5) * S;
  float len = abs(D.x) * ratio + abs(D.y);
  float halfWidth = 0.5 * (abs(D.y) * ratio + abs(D.x));
  float t = dot(q, D) + 0.5 * len;
  float c = dot(q, N);
  float x = abs(c);
  float side = c < 0.0 ? -1.0 : 1.0;

  float a = clamp(p / 0.62, 0.0, 1.0);
  float drive = a * a * (3.0 - 2.0 * a);
  float tip = len * drive;
  float b = clamp((p - 0.5) / 0.5, 0.0, 1.0);
  float apart = b * b;
  float k = tan(radians(opening));

  float wedge = k * max(tip - t, 0.0);
  // the halves only come apart where the wedge has split them, leaning out as they fall away
  float w = wedge + (halfWidth + 0.02 + 0.3 * (len - t)) * apart * clamp(1.0 + (tip - t) / EDGE, 0.0, 1.0);

  // the incoming image's leading edge rides on the wedge point
  vec4 to = getToColor((q + D * len * (1.0 - drive)) / S + 0.5);
  float shadow = shading * 0.7 * exp(-max(w - x, 0.0) * cos(radians(opening)) / 0.035) * (1.0 - apart) * clamp(1.0 + (w - x) / EDGE, 0.0, 1.0);
  to.rgb *= 1.0 - shadow;

  // part of the push bunches the picture up against the wedge, the rest slides it away rigidly;
  // the bunching relaxes once the halves are free
  float d = max(x - w, 0.0);
  float bunch = wedge * squash * (1.0 - apart);
  float fall = exp(-d / FALLOFF);
  vec2 qf = (t - 0.5 * len) * D + side * (d + bunch * (1.0 - fall)) * N;
  vec4 from = getFromColor(qf / S + 0.5);

  float ridge = bunch / FALLOFF * fall;
  float lip = 1.0 - smoothstep(0.0, 0.012, d);
  float light = 1.0 + shading * (0.5 * lip * min(ridge, 1.0) - 0.3 * min(ridge, 1.5) * (1.0 - lip) * (1.0 - 0.5 * fall));

  float grow = clamp(p / 0.08, 0.0, 1.0);
  float crackLen = 0.2 * grow;
  float ahead = t - tip;
  if (ahead > 0.0 && ahead < crackLen) {
    float xc = smoothstep(0.0, 0.02, ahead) * (0.006 * zigzag(t * 21.0) + 0.0025 * zigzag(t * 57.0 + 0.3));
    float taper = 1.0 - ahead / crackLen;
    float width = 0.0015 + 0.004 * taper;
    light *= 1.0 - 0.75 * (1.0 - smoothstep(width, width + EDGE, abs(c - xc))) * taper * grow;
  }
  from.rgb *= light;

  // the cut fades in while the wedge is thinner than EDGE, so nothing shows at the start
  float m = mix(1.0, clamp(0.5 + 0.5 * (x - w) / EDGE, 0.0, 1.0), clamp(w / EDGE, 0.0, 1.0));
  return mix(to, from, m);
}
