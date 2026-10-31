// Author: gre
// License: MIT
// Description: The frame is seen through flowing liquid glass that bends the outgoing image more and more, with rainbow fringes, flares up as the incoming image takes over, then calms down and clears
// Tags: distortion, refraction, chromatic-aberration, glow

// @range(0, 0.3) How far the glass bends the image at the peak
uniform float strength; // = 0.15
// @range(0.5, 8) Size of the flowing waves: higher makes smaller waves
uniform float scale; // = 2.5
// @range(0, 1) Spread of the rainbow fringes
uniform float dispersion; // = 0.5
// @range(0, 3) Brightness of the flare at the peak
uniform float brightness; // = 1.0

// the wavelengths sampled from red to violet
const int TAPS = 7;

// the glass surface: smooth waves of a few sizes, warped into each other and flowing over time
float surface(vec2 q, float t) {
  q += 0.45 * vec2(sin(1.3 * q.y + 0.9 * t), sin(1.1 * q.x - 1.2 * t));
  float h = sin(q.x + 0.6 * t) * sin(1.2 * q.y - 0.8 * t);
  h += 0.5 * sin(dot(q, vec2(1.6, -1.2)) + 1.4 * t);
  h += 0.3 * sin(dot(q, vec2(-1.1, 2.9)) - 1.9 * t + 1.7 * sin(0.9 * q.x));
  h += 0.15 * sin(dot(q, vec2(4.3, 3.1)) + 2.6 * t);
  return h;
}

// a hash without sin, to jitter the wavelengths from pixel to pixel
float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// rough spectral response of a wavelength w (0 = red, 1 = violet), in RGB
vec3 spectrum(float w) {
  vec3 c = vec3(
    1.0 - smoothstep(0.0, 0.55, w) + 0.35 * smoothstep(0.75, 1.0, w),
    1.0 - abs(2.0 * w - 1.0) * 1.2,
    smoothstep(0.45, 1.0, w)
  );
  return clamp(c, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // 0 at both ends, 1 in the middle: the glass builds up slowly, then calms down
  float h = 1.0 - abs(2.0 * p - 1.0);
  float amount = h * h * (2.0 - h);

  // the glass refracts along the slope of its surface
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0) * scale;
  float t = 3.0 * p;
  float e = 0.01;
  vec2 slope = vec2(
    surface(q + vec2(e, 0.0), t) - surface(q - vec2(e, 0.0), t),
    surface(q + vec2(0.0, e), t) - surface(q - vec2(0.0, e), t)
  ) / (2.0 * e);
  vec2 offset = slope * strength * amount / scale;
  // the switch to the incoming image, around the peak: it appears through the glass's waves,
  // the crests first, then the troughs
  float wave = clamp(0.5 * surface(q, t), -1.0, 1.0);
  float m = smoothstep(-0.015, 0.015, p - 0.5 + 0.1 * wave);

  // each wavelength bends a little differently: red the least, violet the most
  vec3 color = vec3(0.0);
  vec3 weights = vec3(0.0);
  float alpha = 0.0;
  // jittered wavelengths blend the fringes into a continuous rainbow
  float jitter = hash12(uv * vec2(ratio, 1.0) * 1000.0) - 0.5;
  for (int i = 0; i < TAPS; i++) {
    float w = float(i) / float(TAPS - 1);
    float wj = (float(i) + jitter) / float(TAPS - 1);
    vec2 st = mirror(uv + offset * (1.0 + dispersion * (wj - 0.5) * 1.6));
    vec4 c = mix(getFromColor(st), getToColor(st), m);
    vec3 s = spectrum(w);
    color += s * c.rgb * c.a;
    weights += s;
    alpha += c.a;
  }
  alpha /= float(TAPS);
  color = color / weights / max(alpha, 1e-5);

  // a flare at the peak: the image is pushed toward an overexposed white
  float flare = 2.0 * brightness * pow(h, 8.0);
  color = color * (1.0 + flare) / (1.0 + flare * color);
  color += 0.1 * flare * dot(color, vec3(0.3333));
  return vec4(clamp(color, 0.0, 1.0), alpha);
}
