// Author: OllyOllyOlly
// License: MIT
// Description: The halves of both images slide horizontally in opposite directions, out and in at once
// Tags: slide, split, horizontal

// @param Swap the directions of the halves
uniform bool reverse; // = false

const vec2 boundMin = vec2(0.0, 0.0);
const vec2 boundMax = vec2(1.0, 1.0);

bool inBounds (vec2 p) {
  return all(lessThan(boundMin, p)) && all(lessThan(p, boundMax));
}

vec4 transition (vec2 uv) {
  float modifier = (uv.y > 0.5 ? 1.0 : -1.0) * (reverse ? -1.0 : 1.0) ;
  vec2 fromP = vec2(uv.x + (progress * modifier), uv.y);
  vec2 toP = vec2((uv.x + (progress * modifier)) - modifier, uv.y);

  return inBounds(fromP) ? getFromColor(fromP) : getToColor(toP);
}
