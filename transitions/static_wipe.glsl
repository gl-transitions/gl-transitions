// Author: Ben Lucas
// License: MIT

#define PI 3.14159265359
#define MAX_SPAN 0.5

float rnd (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(10,70)))*
        12345.5453123);
}
    
vec4 transition (vec2 uv) {
  
  float span = MAX_SPAN*pow(sin(PI*progress),0.5);
  
  float mixRatio = progress;
  if(progress != 0.0 && progress != 1.0)
  {
    mixRatio = step(progress, 1.0-uv.y);
  }
  
  vec4 transitionMix = mix(
    getFromColor(uv),
    getToColor(uv),
    mixRatio
  );
  
  float noiseEnvelope = smoothstep(progress-span, progress, 1.0-uv.y) * (1.0 - smoothstep(progress, progress + span, 1.0-uv.y));
  vec4 noise = vec4(vec3(rnd(uv*(1.0+progress))), 1.0);
  

  return mix(transitionMix, noise, noiseEnvelope);
}
