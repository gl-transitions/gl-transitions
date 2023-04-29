// Author: Ben Lucas
// License: MIT

uniform float static_luminosity ; // = 0.8

float rnd (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(10,70)))*
        12345.5453123);
}

vec4 staticNoise (vec2 st, float offset, float luminosity) {
  float staticR = luminosity * rnd(st * vec2(offset * 2.0, offset * 3.0));
  float staticG = luminosity * rnd(st * vec2(offset * 3.0, offset * 5.0));
  float staticB = luminosity * rnd(st * vec2(offset * 5.0, offset * 7.0));
  return vec4(staticR, staticG, staticB, 1.0);
}

float staticIntensity(float t)
{
  return pow(abs(2.0*(t-0.5)),2.0);
}

vec4 transition (vec2 uv) {

  float baseMix = step(0.5, progress);
  vec4 transitionMix = mix(
    getFromColor(uv),
    getToColor(uv),
    baseMix
  );
  
  vec4 staticColor = staticNoise(uv, progress, static_luminosity);

  float staticThresh = 1.0 - staticIntensity(progress);
  float staticMix = step(rnd(uv), staticThresh);

  return mix(transitionMix, staticColor, staticMix);
}
