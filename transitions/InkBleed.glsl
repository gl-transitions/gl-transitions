// Author: gre
// License: MIT
// Description: The incoming image spreads over the outgoing one like drops of ink in water, blooming from a few points with curling, wispy edges and a darker rim, until it fills the frame
// Tags: ink, organic, fluid, noise

// @range(1, 8, 1) Number of ink drops
uniform float drops; // = 4.0
// @range(0, 1) How far the curling tendrils reach out of the blooms
uniform float tendrils; // = 0.7
// @range(0, 1) How dark the rim of ink at the front of the blooms is
uniform float rim; // = 0.5
// @param Random seed for the drop positions and the swirls
uniform float seed; // = 3.0

float hash (vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise (vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

float fbm (vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * vnoise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 7.3;
    a *= 0.5;
  }
  return v / 0.9375;
}

vec2 fold (vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 transition (vec2 uv) {
  float p = progress;
  vec2 q = vec2(uv.x * ratio, uv.y);
  // swirls: noise warped twice by itself, drifting as the ink spreads
  vec2 o = vec2(seed * 3.1, seed * 1.7);
  vec2 sq = q * 2.2 + o;
  vec2 w1 = vec2(fbm(sq + vec2(0.0, 0.6 * p)), fbm(sq + vec2(5.2, 1.3) - vec2(0.5 * p, 0.0)));
  vec2 w2 = vec2(fbm(sq + 3.0 * w1 + vec2(1.7, 9.2)), fbm(sq + 3.0 * w1 + vec2(8.3, 2.8)));
  float swirl = fbm(sq * 0.8 + 2.5 * w2) - 0.5; // marbled, curling pattern
  vec2 flow = w2 - 0.5;
  float amp = 0.05 + 0.35 * tendrils;
  float n = max(1.0, floor(drops + 0.5));
  float rimW = 0.1;
  float feather = 0.05; // soft, diluted ink around the front
  float margin = 1.2 * amp + rimW + 0.08; // how far the swirls can pull the front back
  float f = -1e3; // > 0 inside the ink
  float fs = -1e3; // the same, only for the drops already fallen, which fades their haze in
  for (int i = 0; i < 8; i++) {
    float fi = float(i);
    if (fi < n) {
      vec2 hs = vec2(fi * 7.13 + seed, fi * 3.71 - seed);
      vec2 c = vec2(mix(0.15, 0.85, hash(hs)) * ratio, mix(0.15, 0.85, hash(hs + 19.7)));
      float start = 0.2 * fi / n;
      float s = clamp((p - start) / (1.0 - start), 0.0, 1.0);
      // distance to the farthest corner: each bloom alone covers the frame in the end
      vec2 m = max(c, vec2(ratio, 1.0) - c);
      float far = length(m) + margin;
      float s3 = s * s * s;
      float r = (far + 0.02) * s * (0.35 + 0.65 * s3 * s3) - 0.02;
      // a drop starts round, then its front curls more and more as it spreads
      float reach = amp * min(1.0, max(r, 0.0) * 5.0);
      float g = r - length(q - c + 1.3 * reach * flow) + reach * 0.9 * swirl;
      f = max(f, g);
      fs = max(fs, g - 0.15 * (1.0 - min(1.0, s * 12.0)));
    }
  }
  float aa = 0.003;
  float inside = smoothstep(-aa, aa, f);
  // feathered wisps of diluted ink, streaked along the swirls, ahead of the front
  float wisp = 1.0 - smoothstep(0.0, 0.08, abs(fbm(sq * 2.0 + 5.0 * w2) - 0.5));
  float soft = smoothstep(-feather, 0.0, fs) * (0.35 + 0.4 * wisp);
  float haze = 0.35 * wisp * (1.0 - smoothstep(0.0, 0.1, -fs));
  float cover = max(inside, max(soft, haze));
  // the ink is denser, and still moving, close to its front
  float edge = 1.0 - smoothstep(0.0, rimW, f);
  vec4 to = getToColor(fold(uv - 0.015 * edge * flow / vec2(ratio, 1.0)));
  to.rgb = mix(to.rgb, to.rgb * to.rgb * 0.7, rim * edge);
  return mix(getFromColor(uv), to, cover);
}
