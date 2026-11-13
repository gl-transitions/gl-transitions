// Author: gre
// License: MIT
// Description: The outgoing image slides away leaving a trail of discrete fading copies of itself, a stroboscopic echo, and the incoming image's echoes converge into place
// Tags: slide, echo, strobe, directional

// @param Direction in which the images slide
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(1, 7, 1) Number of echoes between the two images
uniform int echoes; // = 4
// @range(0.05, 0.6) How long the echoes trail behind each image, as a part of the transition
uniform float trail; // = 0.25
// @range(0, 1) How fast the echoes of the outgoing image fade out into those of the incoming one
uniform float decay; // = 0.5

// width of the anti-aliased edges, along the slide
const float EDGE = 0.002;
// the most echoes, the bound of the loop
const int MAX_ECHOES = 7;

float easeInOut(float t) {
  return t * t * (3.0 - 2.0 * t);
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// coverage of the part of the frame past an edge at x, anti-aliased only inside the frame
float past(float s, float x) {
  return x <= 0.0 ? 1.0 : x >= 1.0 ? 0.0 : clamp((s - x) / EDGE + 0.5, 0.0, 1.0);
}

// the edge between the copies at the time t of the slide
float edgeAt(float t) {
  return easeInOut(clamp(t, 0.0, 1.0));
}

// step j between the two images, from the edge e0 to the edge e1: the echo of the outgoing image
// whose trailing edge is e0, fading out toward the incoming image, over the echo of the incoming
// image whose leading edge is e1
vec4 echoStep(vec2 uv, float s, vec2 shift, float j, float t0, float lag, float n) {
  float e0 = edgeAt(t0 + j * lag);
  float e1 = edgeAt(t0 + (j + 1.0) * lag);
  vec4 a = getFromColor(mirror(uv - shift * e0));
  vec4 b = getToColor(mirror(uv - shift * (e1 - 1.0)));
  vec4 c = mix(b, a, pow((j + 0.5) / n, 0.5 + 2.0 * clamp(decay, 0.0, 1.0)));
  // each copy casts a soft shadow behind it onto the older ones
  c.rgb *= 1.0 - 0.25 * exp(-max(e1 - s, 0.0) / 0.02) * min((e1 - e0) / 0.02, 1.0);
  return c;
}

vec4 transition(vec2 uv) {
  float dl = length(direction);
  vec2 d = dl > 1e-6 ? direction / dl : vec2(1.0, 0.0);
  // s: position along the slide, from 0 (trailing side) to 1 (leading side)
  float ext = abs(d.x) + abs(d.y);
  vec2 shift = d * ext;
  float s = 0.5 + dot(uv - 0.5, d) / ext;

  float n = clamp(float(echoes), 1.0, float(MAX_ECHOES));
  float tr = clamp(trail, 0.05, 0.6);
  float lag = tr / n;
  // the incoming image follows the outgoing one tr behind; the copies of both images sit at
  // the times between them, the stroboscopic echoes of the outgoing image trailing behind it
  // and those of the incoming image ahead of it
  float t0 = progress >= 1.0 ? 1.0 : progress * (1.0 + tr) - tr;
  float eIn = edgeAt(t0);
  float eOut = edgeAt(t0 + tr);

  float wIn = 1.0 - past(s, eIn);
  float wOut = past(s, eOut);
  float wGap = max(1.0 - wIn - wOut, 0.0);
  vec4 c = vec4(0.0);
  if (wGap > 0.0) {
    // the step of this point, and how far it is past the next edge, to anti-alias it
    float jf = 0.0;
    for (int k = 1; k < MAX_ECHOES; k++) {
      float m = float(k);
      if (m >= n) break;
      jf += past(s, edgeAt(t0 + m * lag));
    }
    float j = floor(jf);
    c = echoStep(uv, s, shift, j, t0, lag, n);
    if (jf > j) c = mix(c, echoStep(uv, s, shift, j + 1.0, t0, lag, n), jf - j);
    c *= wGap;
  }
  // the two images on both sides of their echoes
  if (wIn > 0.0) c += wIn * getToColor(mirror(uv - shift * (eIn - 1.0)));
  if (wOut > 0.0) c += wOut * getFromColor(mirror(uv - shift * eOut));
  return c;
}
