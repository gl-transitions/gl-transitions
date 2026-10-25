// Author: haiyoucuv
// License: MIT
// Description: A crossfade in which the colors of one image displace the other
// Tags: displace, distort, blend

vec4 transition (vec2 uv) {

  vec4 coordTo = getToColor(uv);
  vec4 coordFrom = getFromColor(uv);

  return mix(
    getFromColor(mix(uv, coordTo.rg, progress)),
    getToColor(mix(coordFrom.rg, uv, progress)),
    progress
  );

}
