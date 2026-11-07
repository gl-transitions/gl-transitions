// License: MIT
// Author: Sergey Kosarevsky
// Description: The image twists into a round swirl around the center that peaks mid-way, where the outgoing image dissolves into the incoming one, then untwists
// Tags: swirl, rotate, blend
// ( http://www.linderdaum.com )
// ported by gre from https://gist.github.com/corporateshark/cacfedb8cca0f5ce3f7c

// @range(-3, 3) Turns of the swirl at its center at the peak (negative turns clockwise)
uniform float strength; // = 1.0
// @range(0.1, 2) Radius of the swirl, in frame heights
uniform float radius; // = 0.9
// Center of the swirl
uniform vec2 center; // = vec2(0.5, 0.5)

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;
// how much the swirl pulls the image toward its center at the peak
const float ZOOM = 0.12;
// spread of the motion blur, as a fraction of the swirl's speed
const float BLUR = 0.05;
const int TAPS = 12;

// fold the coordinates back into the frame, so the image stays filled without smearing its border
vec2 mirrored(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

vec4 transition(vec2 uv) {
  // the swirl eases in and out, and is exactly 0 at both ends
  float s = sin(PI * progress);
  float amount = s * s;
  // its speed, used for the motion blur, also 0 at both ends
  float speed = PI * sin(TAU * progress);
  // the switch from the outgoing to the incoming image happens around the peak
  float reveal = smoothstep(0.3, 0.7, progress);

  // measured in frame heights, so the swirl is round
  vec2 aspect = vec2(ratio, 1.0);
  vec2 d = (uv - center) * aspect;
  float x = clamp(length(d) / max(radius, 1e-3), 0.0, 1.0);
  // the twist fades out smoothly toward the edge of the swirl
  float falloff = (1.0 - x) * (1.0 - x);
  float twist = strength * TAU * falloff;
  float angle = twist * amount;
  // capped so the blur taps never spread apart into visible streaks
  float spread = clamp(twist * speed * BLUR, -1.2, 1.2);
  // the swirl also slightly pulls the image toward its center
  d *= 1.0 - ZOOM * amount * falloff;

  vec4 col = vec4(0.0);
  float total = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float k = float(i) / float(TAPS - 1) - 0.5;
    float w = 1.0 - abs(k);
    float a = angle + spread * k;
    float c = cos(a);
    float sn = sin(a);
    vec2 q = mirrored(center + vec2(c * d.x - sn * d.y, sn * d.x + c * d.y) / aspect);
    col += mix(getFromColor(q), getToColor(q), reveal) * w;
    total += w;
  }
  return col / total;
}
