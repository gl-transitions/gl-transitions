// Author: salmondx
// License: MIT

uniform float strength; // =0.5

vec4 transition (vec2 uv) {
  vec4 fTex = getFromColor(uv);
  fTex.a = fTex.a * max((1.0 - progress), strength);

  vec4 tTex = getToColor(uv);
  tTex.a = tTex.a * max(progress, strength);

  return mix(fTex, tTex, progress);
}
