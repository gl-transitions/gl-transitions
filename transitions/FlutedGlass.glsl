// Author: gre
// License: MIT
// Description: The scene slides behind a ribbed glass panel whose ribs bend it into narrow shimmering slivers, the incoming image takes its place behind the glass, then the ribs flatten back and it clears
// Tags: glass, distortion, refraction, stripes

// @range(4, 60) Number of ribs across the frame
uniform float ribs; // = 16.0
// @range(0, 3) How strongly each rib bends the image at the peak
uniform float strength; // = 1.2
// @range(-90, 90) Angle of the ribs, in degrees: 0 makes vertical ribs
uniform float angle; // = 0.0

// samples across each rib, to soften the image behind the glass and its grooves
const int TAPS = 6;

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float p = progress;
  // the ribs bulge out until 0.4, stay at their peak while the images switch, then flatten back
  float amount = smoothstep(0.0, 0.4, p) * (1.0 - smoothstep(0.62, 1.0, p));
  // the scene slides behind the glass: the outgoing image leaves, the incoming one arrives,
  // both moving the same way across the ribs (in frame heights)
  float slideOut = 0.3 * p * p;
  float slideIn = -0.3 * (1.0 - p) * (1.0 - p);

  float a = radians(angle);
  // across: the axis across the ribs, in frame heights
  vec2 across = vec2(cos(a), sin(a));
  vec2 fp = (uv - 0.5) * vec2(ratio, 1.0);
  float w = (ratio * abs(across.x) + abs(across.y)) / ribs;
  float u = dot(fp, across) / w;

  // the switch happens at the peak, rib by rib across the panel
  float order = clamp(0.5 + (floor(u) + 0.5) / ribs, 0.0, 1.0);
  float m = smoothstep(0.0, 1.0, clamp((p - 0.41 - 0.14 * order) / 0.04, 0.0, 1.0));

  vec4 color = vec4(0.0);
  float shine = 0.0;
  for (int i = 0; i < TAPS; i++) {
    // spread the samples over a part of the rib, more as the glass bulges
    float j = (float(i) + 0.5) / float(TAPS) - 0.5;
    float ut = u + j * 0.22 * amount;
    // x: position across the rib, -1 to 1; each rib is a lens that squeezes a wider
    // slice of the image into it, bending more and more toward its edges
    float x = 2.0 * fract(ut) - 1.0;
    float bend = strength * amount * x * (0.7 + 0.5 * x * x);
    vec2 q = fp + across * ((ut - u) + bend) * w;
    vec2 st = q / vec2(ratio, 1.0) + 0.5;
    vec4 c = vec4(0.0);
    if (m < 1.0) c += (1.0 - m) * getFromColor(mirror(st + slideOut * across / vec2(ratio, 1.0)));
    if (m > 0.0) c += m * getToColor(mirror(st + slideIn * across / vec2(ratio, 1.0)));
    color += c;
    // a soft highlight on one side of each rib, and shade in the grooves between them
    float k = (x + 0.35) / 0.22;
    shine += 0.22 * exp(-k * k) - 0.18 * pow(abs(x), 6.0);
  }
  color /= float(TAPS);
  shine *= amount / float(TAPS);
  color.rgb = clamp(color.rgb + shine * color.a, 0.0, 1.0);
  return color;
}
