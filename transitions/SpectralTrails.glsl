// Author: gre
// License: MIT
// Description: The image whirls round and zooms while each color of the spectrum lives at a slightly different moment, red leading and violet trailing, so everything drags rainbow streaks; the swap itself runs through the spectrum, and the colors lock back into white light as the incoming image settles
// Tags: rotate, zoom, rainbow, chromatic, motion-blur

// @range(0.1, 0.6) Delay between red and violet, as a part of the transition
uniform float lag; // = 0.38
// @range(-1, 1) Turns made by the images
uniform float turn; // = 0.5
// @range(1, 3) How far the images zoom
uniform float zoom; // = 1.5
// @range(0, 1) Extra saturation of the streaks
uniform float vividness; // = 0.7

const float TAU = 6.2831853;
const int TAPS = 32;

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

// continuous, so that every target jitters the same
float grain(vec2 p) {
  vec2 c = floor(p), f = p - c;
  return mix(
    mix(hash(c), hash(c + vec2(1.0, 0.0)), f.x),
    mix(hash(c + vec2(0.0, 1.0)), hash(c + 1.0), f.x),
    f.y);
}

vec3 spectrum(float x) {
  return max(vec3(0.0), 1.0 - abs(x - vec3(0.12, 0.5, 0.88)) / vec3(0.4, 0.36, 0.4));
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * asp;
  float jitter = grain(uv * asp * 360.0);
  float lz = 2.0 * log2(max(zoom, 0.1));
  vec3 sum = vec3(0.0);
  vec3 norm = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float x = (float(i) + jitter) / float(TAPS);
    float t = clamp(progress + lag * (progress - x), 0.0, 1.0);
    float e = t * t * (3.0 - 2.0 * t);
    float late = step(0.5, e);
    float a = TAU * turn * (e - late);
    float c = cos(a), s = sin(a);
    vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * exp2(-lz * (e - late));
    q = fold(q / asp + 0.5);
    vec4 tap = late > 0.5 ? getToColor(q) : getFromColor(q);
    vec3 w = spectrum(x) * tap.a;
    sum += tap.rgb * w;
    norm += w;
    alpha += tap.a;
  }
  vec3 col = sum / max(norm, vec3(1e-5));
  float l = dot(col, vec3(0.299, 0.587, 0.114));
  float act = smoothstep(0.05, 0.4, progress) * (1.0 - smoothstep(0.6, 0.95, progress));
  return vec4(clamp(mix(vec3(l), col, 1.0 + vividness * act), 0.0, 1.0), alpha / float(TAPS));
}
