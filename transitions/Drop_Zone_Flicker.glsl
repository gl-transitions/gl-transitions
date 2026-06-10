// Author: bread
// License: MIT
// Drop_Zone_Flicker.glsl
// gl-transitions compatible: progress, ratio, getFromColor, getToColor
uniform float frameRate;    // = 24.0
uniform float rgbOffset;    // = 0.014
uniform float blockAmount;  // = 0.72
uniform float ghostAmount;  // = 0.62
uniform float redCyan;      // = 0.58
uniform float scanline;     // = 0.075

float sat(float x) {
  return clamp(x, 0.0, 1.0);
}

float hash12(vec2 p) {
  p = fract(p * vec2(443.8975, 397.2973));
  p += dot(p, p.yx + 19.19);
  return fract(p.x * p.y);
}

vec2 safeUv(vec2 uv) {
  return clamp(uv, vec2(0.001), vec2(0.999));
}

// 24fps reference-matched reveal curve.
// Non-monotonic on purpose: the reference flashes back to the old clip.
float frameReveal(float f) {
  if (f < 0.5) return 0.00;
  if (f < 1.5) return 0.28;
  if (f < 2.5) return 0.43;
  if (f < 3.5) return 0.46;
  if (f < 4.5) return 0.38;
  if (f < 5.5) return 0.48;
  if (f < 6.5) return 0.26;
  if (f < 7.5) return 0.10;
  if (f < 8.5) return 0.00;
  if (f < 9.5) return 0.00;
  if (f < 10.5) return 0.30;
  if (f < 11.5) return 0.58;
  if (f < 12.5) return 1.00;
  if (f < 13.5) return 0.70;
  if (f < 14.5) return 0.42;
  if (f < 15.5) return 0.55;
  if (f < 16.5) return 0.72;
  if (f < 17.5) return 0.88;
  if (f < 18.5) return 0.34;
  if (f < 19.5) return 0.48;
  if (f < 20.5) return 0.56;
  if (f < 21.5) return 0.76;
  if (f < 22.5) return 0.93;
  return 1.00;
}

float frameGlitch(float f) {
  if (f < 0.5) return 0.00;
  if (f < 6.5) return 0.92;
  if (f < 10.5) return 0.38;
  if (f < 11.5) return 0.78;
  if (f < 12.5) return 0.12;
  if (f < 17.5) return 0.74;
  if (f < 22.5) return 0.88;
  if (f < 23.5) return 0.28;
  return 0.00;
}

vec4 chromaFrom(vec2 uv, float amt) {
  vec2 o = vec2(amt, 0.0);
  return vec4(
    getFromColor(safeUv(uv + o)).r,
    getFromColor(safeUv(uv)).g,
    getFromColor(safeUv(uv - o)).b,
    1.0
  );
}

vec4 chromaTo(vec2 uv, float amt) {
  vec2 o = vec2(amt, 0.0);
  return vec4(
    getToColor(safeUv(uv - o)).r,
    getToColor(safeUv(uv)).g,
    getToColor(safeUv(uv + o)).b,
    1.0
  );
}

float blockMask(vec2 uv, float f) {
  vec2 big = floor(uv * vec2(4.0, 2.0));
  vec2 small = floor(uv * vec2(8.0, 4.0));

  float wide = step(0.48, hash12(vec2(big.x, f * 1.37)));
  float chunks = step(0.56, hash12(small + vec2(f * 2.11, f * 0.73)));

  float verticalCut = smoothstep(
    -0.035,
    0.035,
    uv.x - mix(0.18, 0.78, hash12(vec2(f, 4.7)))
  );

  return sat(mix(wide, chunks, 0.38) * 0.72 + verticalCut * 0.28);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  float f = floor(progress * frameRate);
  float reveal = frameReveal(f);
  float glitch = frameGlitch(f);

  float rnd = hash12(vec2(f, 9.13));
  vec2 jitter = vec2(
    (rnd - 0.5) * 0.042,
    (hash12(vec2(f, 2.71)) - 0.5) * 0.010
  ) * glitch;

  vec2 fromUv = safeUv(uv + jitter);
  vec2 toUv = safeUv(uv - jitter * 0.55);

  float block = blockMask(uv, f);
  float localReveal = sat(
    reveal +
    (block - 0.5) * blockAmount * glitch +
    (hash12(vec2(f, floor(uv.y * 9.0))) - 0.5) * 0.18 * glitch
  );

  localReveal = smoothstep(0.22, 0.78, localReveal);

  vec4 oldClip = chromaFrom(fromUv, rgbOffset * glitch);
  vec4 newClip = chromaTo(toUv, rgbOffset * glitch);

  vec4 color = mix(oldClip, newClip, localReveal);

  float leftWash = (1.0 - smoothstep(0.10, 0.78, uv.x)) * glitch;
  float cyanWash = smoothstep(0.08, 0.62, uv.x) * (1.0 - smoothstep(0.86, 1.0, uv.x)) * glitch;

  vec3 redGhost = oldClip.rgb * vec3(1.34, 0.42, 0.38);
  vec3 cyanGhost = newClip.rgb * vec3(0.48, 1.12, 1.24);

  color.rgb = mix(color.rgb, redGhost, leftWash * redCyan * 0.42);
  color.rgb = mix(color.rgb, cyanGhost, cyanWash * redCyan * 0.30);

  // Keeps the old circular "drop zone" visible as a translucent flash,
  // especially after the first full new-frame hit.
  float oldReturn = glitch * (1.0 - smoothstep(0.94, 1.0, reveal));
  oldReturn *= 0.18 + 0.52 * (1.0 - abs(localReveal - 0.5) * 2.0);
  color.rgb = mix(color.rgb, oldClip.rgb, oldReturn * ghostAmount);

  float lines = sin((uv.y + f * 0.017) * 1080.0);
  color.rgb += lines * scanline * glitch;

  float exposurePulse = (hash12(vec2(f, 12.4)) - 0.35) * 0.10 * glitch;
  color.rgb += exposurePulse;

  return vec4(sat(color.r), sat(color.g), sat(color.b), 1.0);
}
