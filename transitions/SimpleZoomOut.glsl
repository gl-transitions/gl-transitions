// Author: Tianshuo
// License: MIT
// Description: The incoming image zooms out into place while fading in
// Tags: zoom, fade


// @range(0.2, 1) How quickly the zoom happens
uniform float zoom_quickness; // = 0.8
// @param Fade instead of cutting to the incoming image
uniform bool fade; // = true
vec2 zoom(vec2 uv, float amount) {
  return 0.5 + ((uv - 0.5) * (1.0-amount));	
}

vec4 transition (vec2 uv) {
  float nQuick = clamp(zoom_quickness,0.2,1.0);
  return mix(
    getFromColor(uv),
    getToColor(zoom(uv,1.-smoothstep(1.-nQuick, 1., progress))),
   fade?smoothstep(1.0-nQuick, 1., progress):(progress<1.0-nQuick?0.0:1.0)
  );
}
