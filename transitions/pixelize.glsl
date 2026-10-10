// Author: gre
// License: MIT
// Description: Both images pixelate, crossfade, then sharpen again
// Tags: pixelate, blend
// forked from https://gist.github.com/benraziel/c528607361d90a072e98

// minimum number of squares (when the effect is at its higher level)
// @param Number of squares at the strongest pixelation
uniform ivec2 squaresMin; // = ivec2(20)
// zero disable the stepping
// @param Number of pixelation steps; 0 for a continuous effect
uniform int steps; // = 50

vec4 transition(vec2 uv) {
  float d = min(progress, 1.0 - progress);
  float dist = steps>0 ? ceil(d * float(steps)) / float(steps) : d;
  vec2 squareSize = 2.0 * dist / vec2(squaresMin);
  vec2 p = dist>0.0 ? (floor(uv / squareSize) + 0.5) * squareSize : uv;
  return mix(getFromColor(p), getToColor(p), progress);
}
