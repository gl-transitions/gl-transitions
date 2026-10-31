// Author: gre
// License: MIT
// Description: The camera tilts fast from the outgoing image to the incoming one, set edge to edge at an angle above it, streaking both in perspective with a vertical motion blur
// Tags: 3d, rotate, motion-blur, vertical

// @param Tilt the camera down to an incoming image below instead of above
uniform bool down; // = false
// @range(0, 1) Length of the motion blur along the tilt
uniform float blur; // = 0.5
// @range(0, 1) How much the color channels split apart as the tilt speeds up
uniform float chroma; // = 0.5
// @range(0, 1) Strength of the perspective (field of view of the camera)
uniform float perspective; // = 0.7

const float PI = 3.141592653589793;
const int SAMPLES = 24;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// fold the coordinates back into the image, only a safety at the far edges
vec2 mirror(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

// how far the camera has tilted at time t, from 0 to 1: slow start, whip in the middle, slow landing
float tilt(float t) {
  float h = 1.0 - abs(2.0 * t - 1.0);
  float e = 0.5 * h * h * h * h;
  return t < 0.5 ? e : 1.0 - e;
}

vec4 transition(vec2 uv) {
  float p = progress;
  float h = 1.0 - abs(2.0 * p - 1.0); // 0 at both ends, 1 in the middle
  // the shutter is open longer as the tilt speeds up, and closed at both ends
  float shutter = blur * 0.25 * h * h;
  // the images are two faces of a drum around the camera, each filling the frame from the
  // middle: they meet edge to edge at the angle of the field of view, which the camera turns by
  float halfFov = mix(15.0, 45.0, perspective) * PI / 180.0;
  float dist = 0.5 / tan(halfFov);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  if (down) q.y = -q.y;
  float jitter = hash(uv * vec2(ratio, 1.0) * 731.0);
  vec3 color = vec3(0.0);
  vec3 weight = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < SAMPLES; i++) {
    float s = (float(i) + jitter) / float(SAMPLES) - 0.5;
    float t = clamp(p + s * shutter, 0.0, 1.0);
    float a = 2.0 * halfFov * tilt(t);
    // zoom in just enough that the faces always cover the frame, wherever their edge is
    vec2 r = q * cos(halfFov) / cos(halfFov - a);
    // the ray in the frame of the outgoing face, then of the incoming one
    float c0 = cos(a), s0 = sin(a);
    vec2 d0 = vec2(r.y * c0 + dist * s0, dist * c0 - r.y * s0);
    float b = a - 2.0 * halfFov;
    float c1 = cos(b), s1 = sin(b);
    vec2 d1 = vec2(r.y * c1 + dist * s1, dist * c1 - r.y * s1);
    // the ray leaves the drum through the nearest face
    bool incoming = d1.y > d0.y;
    vec2 d = incoming ? d1 : d0;
    vec2 hit = dist / d.y * vec2(r.x, d.x);
    if (down) hit.y = -hit.y;
    vec2 suv = mirror(hit / vec2(ratio, 1.0) + 0.5);
    vec4 col = incoming ? getToColor(suv) : getFromColor(suv);
    // red trails behind and blue leads along the motion: the channels split with the speed
    vec3 w = max(vec3(1.0 - 4.0 * chroma * s, 1.0, 1.0 + 4.0 * chroma * s), 0.0);
    color += col.rgb * col.a * w;
    weight += col.a * w;
    alpha += col.a;
  }
  return vec4(color / max(weight, vec3(1e-5)), alpha / float(SAMPLES));
}
