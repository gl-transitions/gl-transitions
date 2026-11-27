// Author: gre
// License: MIT
// Description: Colored grain rises over the outgoing image while its detail melts into soft blobs, like the first steps of an image generator; then the sampler runs backward and the incoming image is generated out of the noise, broad colored masses first and fine detail last
// Tags: noise, grain, diffusion, generative, blur
// Preview: 0.45

// @range(4, 60, 1) Sampler steps: how many times the grain is redrawn over the transition
uniform float steps; // = 28.0
// @range(40, 400) Grain cells across the image height
uniform float grain; // = 150.0
// @range(0.2, 1) Peak amount of noise
uniform float strength; // = 0.8

vec3 hash3(vec3 p) {
  p = fract(p * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yxz + 33.33);
  return fract((p.xxy + p.yxx) * p.zyx);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float sigma = strength * sin(3.14159265 * progress);
  // the picture fades as the noise rises, as in diffusion samplers
  float signal = sqrt(max(1.0 - sigma * sigma, 0.0));
  float m = smoothstep(0.18, 0.74, progress);
  float r = 0.12 * sigma * sigma;
  vec2 cell = floor(uv * vec2(ratio, 1.0) * grain);
  float spin = 6.2831853 * hash3(vec3(cell, -5.0)).x;
  vec4 a0 = getFromColor(uv), b0 = getToColor(uv);
  vec4 a = a0, b = b0;
  for (int i = 1; i < 13; i++) {
    float fi = float(i);
    // golden-angle spiral, turned per grain cell so the blur reads as grain rather than ghost copies
    float t = fi * 2.39996 + spin;
    vec2 s = mirror(uv + r * sqrt(fi / 12.0) * vec2(cos(t) / ratio, sin(t)));
    a += getFromColor(s);
    b += getToColor(s);
  }
  vec4 x0 = mix(a, b, m) / 13.0;
  float k = floor(progress * steps);
  vec3 n = hash3(vec3(cell, k)) + hash3(vec3(cell + 17.0, k + 3.1)) + hash3(vec3(cell - 9.0, k + 7.7)) - 1.5;
  vec3 x = signal * (x0.rgb * 2.0 - 1.0) + sigma * 1.1 * n;
  return vec4(clamp(x * 0.5 + 0.5, 0.0, 1.0), x0.a);
}
