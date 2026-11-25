// Author: gre
// License: MIT
// Description: The change lands on two beats: the first punch swaps only the light and color masses, so the outgoing picture's details stand drawn over the incoming one's blurred colors; the second snaps the details over too
// Tags: rhythm, beat, punch, blur, zoom
// Preview: 0.45

// @param How far each beat punches in
// @range(0, 0.4)
uniform float punch; // = 0.16
// @param Size of the blur that separates the masses from the details, in frame heights
// @range(0.02, 0.12)
uniform float spread; // = 0.07

const int TAPS = 14;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

float beat(float t) {
  return t < 0.0 ? 0.0 : t * 22.2 * exp(1.0 - t * 22.0);
}

vec4 transition(vec2 uv) {
  vec2 p = uv - 0.5;
  float low = smoothstep(0.2, 0.28, progress);
  float high = smoothstep(0.6, 0.68, progress);
  float kick = beat(progress - 0.2), snare = beat(progress - 0.6) * (1.0 - smoothstep(0.8, 1.0, progress));
  float split = smoothstep(0.02, 0.24, progress) * (1.0 - smoothstep(0.6, 0.95, progress));
  vec2 pl = p * (1.0 - punch * kick) + 0.5;
  vec2 ph = p * (1.0 - 0.1 * split - punch * snare) + 0.5;
  vec2 r = spread * split / vec2(ratio, 1.0);
  float jit = fract(52.9829189 * fract(dot(floor(uv * vec2(ratio, 1.0) * 1080.0 + 0.283), vec2(0.06711056, 0.00583715))));
  float gain = 1.0 + 0.6 * split;
  vec4 base = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float f = float(i);
    float a = f * 2.4 + 0.9 * jit;
    vec2 d = sqrt((f + jit) / float(TAPS)) * vec2(cos(a), sin(a)) * r;
    // during a swap the taps pass to the incoming picture one by one
    float turn = mod(f * 5.0, float(TAPS));
    float l = clamp(low * float(TAPS) - turn, 0.0, 1.0);
    float h = clamp(high * float(TAPS) - turn, 0.0, 1.0) * gain;
    if (l < 1.0) base += (1.0 - l) * pm(getFromColor(mirror(pl + d)));
    if (l > 0.0) base += l * pm(getToColor(mirror(pl + d)));
    if (h < gain) base -= (gain - h) * pm(getFromColor(mirror(ph + d)));
    if (h > 0.0) base -= h * pm(getToColor(mirror(ph + d)));
  }
  base /= float(TAPS);
  base += gain * mix(pm(getFromColor(mirror(ph))), pm(getToColor(mirror(ph))), high);
  base.rgb *= 1.0 + 0.3 * (kick + snare);
  base = clamp(base, 0.0, 1.0);
  return base.a > 0.0 ? vec4(min(base.rgb / base.a, 1.0), base.a) : vec4(0.0);
}
