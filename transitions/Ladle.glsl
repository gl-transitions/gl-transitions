// Author: gre
// License: MIT
// Description: Ladleful after ladleful of the incoming picture is poured into the outgoing one; each pour spreads as a round pool that shoves everything around it aside, squeezing the outgoing picture and the earlier pools into thin veins, until a last big pour pushes the rest out of the frame
// Tags: liquid, marbling, organic, circles, distort, reveal

// @range(1, 9, 1) Number of pours, the last one filling the frame
uniform float pours; // = 7.0

const int N = 9;

float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec4 transition(vec2 uv) {
  vec2 p = vec2(uv.x * ratio, uv.y);
  float n = clamp(floor(pours), 1.0, float(N));
  vec4 acc = vec4(0.0);
  float T = 1.0;
  // newest pour first: each one pushes the older pools and the outgoing picture outward
  for (int i = 0; i < N; i++) {
    float k = float(N - 1 - i);
    if (k < n) {
      bool last = k == n - 1.0;
      float t0 = 0.72 * k / n;
      float s = clamp((progress - t0) / (last ? 1.0 - t0 : 0.3), 0.0, 1.0);
      s = last ? s * s * (3.0 - 2.0 * s) : 1.0 - (1.0 - s) * (1.0 - s) * (1.0 - s);
      vec2 c = vec2(
        (0.15 + 0.7 * fract(0.31 + k * 0.618)) * ratio,
        0.18 + 0.64 * fract(0.77 + k * 0.4142 + 0.2 * hash11(k + 3.0))
      );
      vec2 far = max(c, vec2(ratio, 1.0) - c);
      float rmax = last ? length(far) * 1.08 : 0.13 + 0.1 * hash11(k * 5.7 + 2.0) + 0.12 * k / n;
      float r = rmax * s;
      vec2 d = p - c;
      float l = length(d);
      float a = (1.0 - smoothstep(r - 0.004, r, l)) * step(0.0005, r);
      acc += T * a * getToColor(vec2(p.x / ratio, p.y));
      T *= 1.0 - a;
      // area-preserving drop of paper marbling: the outside moves out by exactly the pool's area
      p = c + d * sqrt(max(0.0, 1.0 - r * r / max(l * l, 1e-6)));
    }
  }
  return acc + T * getFromColor(vec2(p.x / ratio, p.y));
}
