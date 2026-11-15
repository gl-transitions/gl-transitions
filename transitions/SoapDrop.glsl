// Author: gre
// License: MIT
// Description: A drop of soap touches the outgoing image, which floats on water like a skin: the skin rushes away from the drop and piles up into a glossy, wrinkled rim that is shoved out of the frame, leaving the incoming image under clear, rippling water
// Tags: liquid, surface-tension, push, radial, physical

// @param Where the drop touches the skin
uniform vec2 center; // = vec2(0.42, 0.56)
// @range(0, 1) How much the piled-up skin wrinkles
uniform float crumple; // = 0.8

const float TAU = 6.2831853;
const float AA = 0.002;
const vec3 LIGHT = vec3(-0.45, 0.55, 0.7);
const vec2 LIGHT_XY = vec2(-0.633, 0.774);
const vec3 HALFWAY = vec3(-0.244, 0.299, 0.923);

float sdHash(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

// periodic with period n so the angle wrap leaves no seam
float sdNoise(float x, float n) {
  float i = floor(x);
  float f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(sdHash(mod(i, n)), sdHash(mod(i + 1.0, n)), f);
}

vec2 sdMirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// offset keeps atan defined at the drop's exact center
float sdAngle(vec2 q) {
  return atan(q.y, q.x + 1e-9) / TAU + 0.5;
}

float sdFront(float th, float R) {
  return R * (1.0 + 0.08 * crumple * (sdNoise(th * 7.0, 7.0) + 0.5 * sdNoise(th * 19.0, 19.0) - 0.75));
}

float sdHeight(vec2 q, float R0, float L) {
  float r = length(q);
  float th = sdAngle(q);
  float R = sdFront(th, R0);
  float d = max(r - R, 0.0);
  float comp = R / L * exp(-d / L);
  float T = comp / (1.0 + comp);
  float wob = 9.0 * sdNoise(th * 13.0, 13.0) + 7.0 * sdNoise(th * 37.0, 37.0);
  // angular detail would crowd into spikes on a small disc
  float folds = sin(d * 110.0 + wob) * sdNoise(th * 53.0 + d * 40.0, 53.0) * smoothstep(0.05, 0.3, R);
  float lip = 1.0 - exp(-d / 0.004);
  return 0.008 * T * lip * (1.0 + 1.4 * crumple * T * folds);
}

vec4 transition(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  vec2 q = (uv - center) * a;
  float r = length(q);
  vec2 dir = q / max(r, 1e-5);
  float th = sdAngle(q);
  float rmax = length(max(center, 1.0 - center) * a);

  float t = progress;
  float e = t * (1.4 - 0.4 * t);
  float L = 0.02 + 0.05 * e;
  // the lowest point of the noisy front still clears the farthest corner at the end
  float R0 = e * (rmax + 0.02) / (1.0 - 0.06 * crumple);
  float R = sdFront(th, R0);

  float d = max(r - R, 0.0);
  float fall = exp(-d / L);
  float s = max(r - R * fall, 0.0);
  float comp = R / L * fall;
  float T = comp / (1.0 + comp);

  const vec2 EPS = vec2(0.0015, 0.0);
  vec2 grad = vec2(
    sdHeight(q + EPS, R0, L) - sdHeight(q - EPS, R0, L),
    sdHeight(q + EPS.yx, R0, L) - sdHeight(q - EPS.yx, R0, L)
  ) / (2.0 * EPS.x);
  vec3 n = normalize(vec3(-grad, 1.0));
  float diffuse = max(1.0 + 0.9 * (dot(n, LIGHT) - LIGHT.z), 0.0);
  // subtracting the flat surface's highlight keeps the untouched skin exact
  float spec = max(pow(max(dot(n, HALFWAY), 0.0), 50.0) - pow(HALFWAY.z, 50.0), 0.0);

  vec2 suv = center + (dir * s - grad * 0.004) / a;
  vec4 skin = getFromColor(sdMirror(suv));
  skin.rgb *= diffuse * (1.0 - 0.18 * T);
  skin.rgb += 0.6 * spec * T * skin.a;

  float behind = max(R - r, 0.0);
  float calm = 1.0 - t;
  float k = behind * 70.0 - t * 38.0;
  float env = calm * calm * exp(-behind * 3.0);
  float wave = 0.009 * sin(k) + 0.005 * sin(k * 0.43 + 1.7);
  vec4 water = getToColor(sdMirror(uv - dir * env * wave / a));
  water.rgb *= 1.0 + 0.25 * env * cos(k) * dot(dir, LIGHT_XY);
  float shadow = T * exp(-behind / 0.03) * (0.5 + 0.5 * dot(dir, LIGHT_XY));
  water.rgb *= 1.0 - 0.45 * calm * shadow;

  float m = mix(1.0, smoothstep(-AA, AA, r - R), smoothstep(0.0, 4.0 * AA, R));
  return mix(water, skin, m);
}
