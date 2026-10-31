// Author: gre
// License: MIT
// Description: A fast camera pan that streaks both images with motion blur, the incoming one arriving from the opposite side
// Tags: slide, motion-blur, directional

// @param Direction in which the images move
uniform vec2 direction; // = vec2(-1.0, 0.0)
// @range(0, 1) Length of the motion blur at full speed
uniform float blur; // = 0.4

const int SAMPLES = 24;

// The panned strip: the outgoing image, then the incoming one behind it
vec4 strip(vec2 q, vec2 d) {
  vec2 qt = q + d;
  // which side of the seam between the two images (works for diagonals too)
  if (dot(q - 0.5, -d) < 0.5 * dot(d, d)) {
    return getFromColor(clamp(q, 0.0, 1.0));
  }
  return getToColor(clamp(qt, 0.0, 1.0));
}

float rand(vec2 co) {
  return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 transition(vec2 uv) {
  vec2 d = sign(direction);
  // ease in and out: slow start, whip in the middle, slow landing
  float p = progress;
  float h = 1.0 - abs(2.0 * p - 1.0); // 0 at both ends, 1 in the middle
  // mostly cubic, with a bit of linear so that it starts moving at once
  float e = 0.5 * h * (0.1 + 0.9 * h * h);
  float pos = p < 0.5 ? e : 1.0 - e;
  float len = blur * h * (0.1 + 2.7 * h * h) / 2.8; // follows the speed

  vec2 q = uv - d * pos;
  // average along the motion, jittered to hide the sample steps
  float jitter = rand(uv);
  vec3 color = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < SAMPLES; i++) {
    float t = (float(i) + jitter) / float(SAMPLES) - 0.5;
    vec4 c = strip(q + d * t * len, d);
    color += c.rgb * c.a;
    alpha += c.a;
  }
  return vec4(color / max(alpha, 1e-5), alpha / float(SAMPLES));
}
