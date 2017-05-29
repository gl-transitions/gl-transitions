// Author: gre
// License: MIT
// forked from https://gist.github.com/benraziel/c528607361d90a072e98

uniform vec2 squaresMin/* = vec2(20.0) */; // minimum number of squares (when the effect is at its higher level)
uniform float steps /* = 50 */; // zero disable the stepping

vec4 transition(vec2 uv) {
  float dist = min(progress, 1.0 - progress);
  dist = steps>0.0 ? ceil(dist * steps) / steps : dist;
  vec2 squareSize = 2.0 * dist / squaresMin;
  vec2 p = dist>0.0 ? (floor(uv / squareSize - 0.5) + 0.5) * squareSize : uv;
  return mix(getFromColor(p), getToColor(p), progress);
}

