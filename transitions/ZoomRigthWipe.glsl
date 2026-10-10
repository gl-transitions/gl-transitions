// Author: Handk
// License: MIT
// Description: Zooms into the outgoing image, then the incoming one wipes in from left to right
// Tags: zoom, wipe, horizontal

// @param Part of the first half spent zooming (capped at 0.5)
uniform float zoom_quickness; // = 0.8
vec2 zoom(vec2 uv, float amount) {
  if(amount<0.5)
  return 0.5 + ((uv - 0.5) * (1.0-amount));
  else
  return 0.5 + ((uv - 0.5) * (amount));
  
}

vec4 transition (vec2 uv) {
  float nQuick = clamp(zoom_quickness,0.0,0.5);
  if(progress<0.5){
    vec4 c= mix(
      getFromColor(zoom(uv, smoothstep(0.0, nQuick, progress))),
      getToColor(uv),
     step(0.5, progress)
    );
    
    return c;
  }
  else{
    vec2 p=uv.xy/vec2(1.0).xy;
    vec4 d=getFromColor(p);
    vec4 e=getToColor(p);
    vec4 f= mix(d, e, step(0.0+p.x,(progress-0.5)*2.0));
    
    return f;
  }
}
