// Author: gre
// License: MIT
// Description: The frame wraps around a drum that rolls up, the outgoing image turning away over its top in a motion blur and the incoming one coming around from below and unrolling flat
// Tags: 3d, roll, motion-blur, vertical, chromatic

// @range(0, 1) How much the frame wraps around the drum
uniform float curvature; // = 0.8
// @range(0, 1) Length of the motion blur at full speed
uniform float blur; // = 0.5
// @range(0, 1) How much the drum darkens as it turns away
uniform float shading; // = 0.6
// @range(0, 1) Amount of RGB split along the roll, growing with speed
uniform float chroma; // = 0.5
// @param Roll downward instead, the incoming image coming around from above
uniform bool downward; // = false

const int SAMPLES = 24;
// the half angle of the drum seen in the frame height, at full curvature
const float MAX_ANGLE = 1.1;
// distance from the camera to the drum's axis, in drum radii
const float DIST = 2.6;
// how much the horizontal lines arc away from the middle, per frame height squared
const float ARC = 0.12;

float hash(vec2 c) {
  vec2 q = fract(c * vec2(0.1031, 0.1030));
  q += dot(q, q.yx + 33.33);
  return fract((q.x + q.y) * q.x);
}

// mirrored coordinate, folded back into 0..1
float fold(float v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the strip around the drum: the outgoing image, with the incoming one below it (or above)
vec4 strip(float x, float v) {
  if (downward ? v > 1.0 : v < 0.0) {
    return getToColor(vec2(x, fold(downward ? v - 1.0 : v + 1.0)));
  }
  return getFromColor(vec2(x, fold(v)));
}

// angle on the drum seen at the projected height c (the drum has a radius of 1)
float angleAt(float c) {
  c = clamp(c, -0.98 / sqrt(DIST * DIST - 1.0), 0.98 / sqrt(DIST * DIST - 1.0));
  return asin(c * DIST / sqrt(1.0 + c * c)) - atan(c);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // ease in, roll fast in the middle, ease out
  float h = 1.0 - abs(2.0 * p - 1.0); // 0 at both ends, 1 in the middle
  float e = 0.5 * h * (0.1 + 0.9 * h * h);
  float roll = p < 0.5 ? e : 1.0 - e;
  // the blur and the RGB split stay low until the peak of the roll
  float h3 = h * h * h;
  float peak = h3 * h3;

  // the frame wraps around the drum early, and unwraps to flat sooner as the incoming image settles
  float bend = curvature * (p < 0.5 ? h * (2.0 - h) : h * h * (3.0 - 2.0 * h));
  float phi = MAX_ANGLE * bend + 1e-4;
  float arcK = ARC * bend;
  // the height of the frame's edge, projected with perspective
  float edgeY = sin(phi) / (DIST - cos(phi));

  vec2 n = 2.0 * uv - 1.0;
  // the horizontal lines arc away from the middle, toward the left and right edges
  float xr = n.x * ratio;
  float yn = n.y * (1.0 + arcK * xr * xr);
  float theta = angleAt(yn * edgeY);
  // nearer parts of the drum look wider: the drum is made wide enough to fill the frame's corners
  float thetaCorner = angleAt((1.0 + arcK * ratio * ratio) * edgeY);
  float width = (DIST - 1.0) / (DIST - cos(theta));
  float zoom = (DIST - cos(thetaCorner)) / (DIST - 1.0);
  float x = 0.5 + 0.5 * n.x / (zoom * width);
  // lit from the camera: darker as the surface turns away
  float facing = (DIST * cos(theta) - 1.0)
    / sqrt(1.0 + DIST * DIST - 2.0 * DIST * cos(theta)) ;
  float light = mix(1.0, clamp(facing, 0.0, 1.0), shading);

  // position on the strip (the frame height when flat), rolling the outgoing image away
  float v = 0.5 * (theta / phi + 1.0) + (downward ? roll : -roll);
  float len = 0.5 * blur * peak;
  float split = chroma * peak;
  float jitter = hash(uv * 1000.0);
  vec3 color = vec3(0.0);
  vec3 weight = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < SAMPLES; i++) {
    float t = (float(i) + jitter) / float(SAMPLES) - 0.5;
    vec4 img = strip(x, v + t * len);
    // the channels weigh the samples differently along the roll: an RGB split
    vec3 w = vec3(max(1.0 - 4.0 * split * t, 0.0), 1.0, max(1.0 + 4.0 * split * t, 0.0));
    color += img.rgb * img.a * w;
    weight += img.a * w;
    alpha += img.a;
  }
  color = color / max(weight, vec3(1e-5));
  return vec4(color * light, alpha / float(SAMPLES));
}
