// Author: gre
// License: MIT
// Description: The incoming image pushes the outgoing one out of frame as if seen through a wide-angle lens: the frame bulges and bends the seam while the images speed past, with motion blur, color fringes toward the edges and a light vignette, then flattens back as the push lands
// Tags: slide, push, lens, distort, motion-blur, chromatic-aberration, directional

// @param Direction in which the images move, snapped to the nearest of the 8 horizontal, vertical and diagonal directions
uniform vec2 direction; // = vec2(-1.0, 0.0)
// @range(0, 1) Strength of the lens bulge at the peak
uniform float strength; // = 0.7
// @range(0, 1) Spread of the color fringes toward the edges
uniform float fringe; // = 0.5
// @range(0, 1) Length of the motion blur at full speed
uniform float blur; // = 0.35

const int SAMPLES = 24;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the pushed strip: the outgoing image, and the incoming one next to it all around
vec4 strip(vec2 q, vec2 d) {
  if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) {
    return getFromColor(q);
  }
  return getToColor(mirror(q + d));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  // snap to the nearest of the 8 directions: drop a component under tan(22.5deg) of the other
  vec2 ad = abs(direction);
  vec2 d = sign(direction) * step(0.4142 * max(ad.x, ad.y), ad);
  if (dot(d, d) == 0.0) d = vec2(-1.0, 0.0);
  float p = progress;
  // position: smooth start and landing; the motion blur follows the speed (1.875 at the peak)
  float pos = p * p * p * (p * (p * 6.0 - 15.0) + 10.0);
  float speed = 30.0 * p * p * (1.0 - p) * (1.0 - p) / 1.875;
  float len = clamp(blur, 0.0, 1.0) * 0.25 * speed;
  // the lens and the fringes grow, peak in the middle and relax
  float h = 1.0 - abs(2.0 * p - 1.0);
  float hs = h * h * (3.0 - 2.0 * h);
  float k = clamp(strength, 0.0, 1.0) * 0.75 * hs;
  float ca = clamp(fringe, 0.0, 1.0) * 0.06 * hs;

  // round barrel lens that keeps the corners in place: 1.0 at the corners
  vec2 aspect = vec2(ratio, 1.0);
  float r = length((uv - 0.5) * aspect) / length(0.5 * aspect);
  float r2 = r * r;

  // each tap is both a step of the motion blur and a wavelength: the blue end is drawn in a bit
  // more than the red end, growing toward the edges, so colors split around the contours there
  float jitter = hash(uv * aspect * 731.0);
  vec3 col = vec3(0.0);
  vec3 wsum = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < SAMPLES; i++) {
    float t = (float(i) + 0.5) / float(SAMPLES);
    vec3 w = vec3(t, 1.0 - abs(2.0 * t - 1.0), 1.0 - t);
    vec2 q = 0.5 + (uv - 0.5) * (1.0 - k + k * r2) * (1.0 - ca * (1.0 - t) * r2);
    // spread the blur steps over the wavelengths, so every color gets an even blur; the steps
    // never reach past the two images, at the start and at the landing
    float b = fract((float(i) * 7.0 + jitter) / float(SAMPLES)) - 0.5;
    vec4 c = strip(q - d * clamp(pos + len * b, 0.0, 1.0), d);
    col += w * c.rgb * c.a;
    wsum += w * c.a;
    alpha += c.a;
  }
  col /= max(wsum, vec3(1e-5));
  // a touch of lens vignetting while the lens is strong
  col *= 1.0 - 0.45 * k * r2;
  return vec4(col, alpha / float(SAMPLES));
}
