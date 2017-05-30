// Author: gre
// License: MIT
// forked from https://gist.github.com/benraziel/c528607361d90a072e98

// FIXME something was kinda better in this one: https://gist.github.com/corporateshark/21d2fdd24c706952dc8c

uniform ivec2 squaresMin/* = ivec2(20) */; // minimum number of squares (when the effect is at its higher level)
uniform int steps /* = 50 */; // zero disable the stepping

vec4 transition(vec2 uv) {
  float dist = min(progress, 1.0 - progress);
  dist = steps>0 ? ceil(dist * float(steps)) / float(steps) : dist;
  vec2 squareSize = 2.0 * dist / vec2(squaresMin);
  vec2 p = dist>0.0 ? (floor(uv / squareSize - 0.5) + 0.5) * squareSize : uv;
  return mix(getFromColor(p), getToColor(p), progress);
}
