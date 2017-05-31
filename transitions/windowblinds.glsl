// Author: Fabien Benetou
// License: MIT

vec4 transition (vec2 uv) {
  float t = progress;
  
  if (t>.05 && t<.95 &&mod(floor(uv.y*100.*progress),2.)==0.)
    t*=2.-.5;
  
  return mix(
    getFromColor(uv),
    getToColor(uv),
    t
  );
}
