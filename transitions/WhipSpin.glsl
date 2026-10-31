// Author: gre
// License: MIT
// Description: The camera rolls faster and faster around the center of the frame, streaking the outgoing image in a spin blur, then the incoming one takes over mid-spin and slows to a stop
// Tags: rotate, motion-blur, spin

// @range(-3, 3) Total rotation, in turns, split between the two images (negative turns clockwise)
uniform float turns; // = 1.0
// @range(0, 1) Length of the motion blur along the spin
uniform float blur; // = 0.5
// @range(0, 1) How much the color channels split apart as the spin speeds up
uniform float chroma; // = 0.6
// @range(0, 1) How much the camera zooms in at the fastest point
uniform float zoom; // = 0.25

const float PI = 3.141592653589793;
const int SAMPLES = 24;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// fold the coordinates back into the image so that the rotated frame stays filled
vec2 mirror(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

// the camera's roll angle at time t: the outgoing image speeds up until the middle,
// then the incoming one, already turning, slows down to rest
float rollAngle(float t) {
  float halfTurn = PI * turns;
  if (t < 0.5) {
    float x = 2.0 * t;
    return halfTurn * x * x * x;
  }
  float x = 2.0 - 2.0 * t;
  return -halfTurn * x * x * x;
}

vec4 transition(vec2 uv) {
  float p = progress;
  float h = 1.0 - abs(2.0 * p - 1.0); // 0 at both ends, 1 at the cut
  // the shutter is open longer as the spin speeds up, and closed at both ends
  float shutter = blur * 0.1 * h;
  float scale = 1.0 + zoom * h * h * h;
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float jitter = hash(uv * vec2(ratio, 1.0) * 731.0);
  vec3 color = vec3(0.0);
  vec3 weight = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < SAMPLES; i++) {
    float s = (float(i) + jitter) / float(SAMPLES) - 0.5;
    float t = clamp(p + s * shutter, 0.0, 1.0);
    float a = rollAngle(t);
    float c = cos(a), sn = sin(a);
    vec2 r = vec2(c * q.x + sn * q.y, -sn * q.x + c * q.y) / scale;
    vec2 suv = mirror(r / vec2(ratio, 1.0) + 0.5);
    vec4 col = t < 0.5 ? getFromColor(suv) : getToColor(suv);
    // red trails behind and blue leads along the arc: the channels split with the speed
    vec3 w = max(vec3(1.0 - 4.0 * chroma * s, 1.0, 1.0 + 4.0 * chroma * s), 0.0);
    color += col.rgb * col.a * w;
    weight += col.a * w;
    alpha += col.a;
  }
  return vec4(color / max(weight, vec3(1e-5)), alpha / float(SAMPLES));
}
