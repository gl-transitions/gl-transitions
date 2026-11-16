// Author: gre
// License: MIT
// Description: The outgoing image is a body of water held back by a dam on one side: the dam gives way, its top sinks toward the open side into a long rippling slope with a glossy, foaming surface that rushes out of the frame, stretching the picture along the flow, and the rest drains away, revealing the incoming image
// Tags: liquid, water, gravity, flow, directional, physical

// @range(0, 1) Strength of the glossy highlight along the water surface
uniform float gloss; // = 0.6
// @range(0, 1) Amount of foam on the surface, growing where the water runs fastest
uniform float foam; // = 0.6
// @param Flow toward the left instead of the right
uniform bool leftward; // = false

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float vnoise(vec2 v) {
  vec2 i = floor(v);
  vec2 f = fract(v);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
    mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// tau-normalized so tiny tau never squares below mediump range
float flowArea(float a, float x, float tau) {
  float p = 2.0 - a / tau;
  float q = 2.0 - x / tau;
  return tau * (p * p * p - q * q * q) / 27.0;
}

vec4 transition(vec2 uv) {
  float t = progress;
  float L = ratio;
  float u = leftward ? 1.0 - uv.x : uv.x;
  // x in frame heights from the dam at the open edge; with unit depth and wave speed the free surface is ((2tau - x) / (3tau))^2
  float x = (u - 1.0) * L;
  float tau = max(1.6 * max(L, 0.8) * pow(t, 1.4), 1e-4);
  float drain = 1.0 - smoothstep(0.45, 1.0, t);

  float a = max(-L, -tau);
  float xc = min(x, 2.0 * tau);
  float M = max(min(xc, a) + L, 0.0) + (xc > a ? flowArea(a, xc, tau) : 0.0);
  float Mt = (a + L) + flowArea(a, 2.0 * tau, tau);

  // r is capped at 2 so r * r stays in mediump range; past sqrt(1 + k) the smooth-min is already 1
  float r = min(max(2.0 * tau - x, 0.0), 6.0 * tau) / (3.0 * tau);
  float k = 0.12;
  float sk = clamp(0.5 + 0.5 * (r * r - 1.0) / k, 0.0, 1.0);
  float hs = mix(r * r, 1.0, sk) - k * sk * (1.0 - sk);
  // the polynomial smooth-min's derivative reduces to (1 - sk) * d(r^2)/dx
  float dhs = -(1.0 - sk) * 2.0 * r / (3.0 * tau);
  // tau has a floor, so the flow fades in to keep the open edge full at progress 0
  float e = smoothstep(0.0, 0.02, t);
  hs = mix(1.0, hs, e);
  dhs *= e;

  float moving = clamp(1.0 - hs, 0.0, 1.0);
  float ramp = min(moving * 4.0, 1.0) * (1.0 - t);
  float ph = 34.0 * x - 60.0 * t;
  float ph2 = 71.0 * x - 115.0 * t + 1.7;
  float wave = (0.014 * sin(ph) + 0.005 * sin(ph2)) * ramp;
  float dwave = (0.014 * 34.0 * cos(ph) + 0.005 * 71.0 * cos(ph2)) * ramp;
  float h = (hs + wave) * drain;
  float slope = (dhs + dwave) * drain;

  float d = h - uv.y;
  float inside = smoothstep(-1e-5, 0.003 * min(t * 20.0, 1.0) + 1e-5, d);
  vec2 src = vec2(mix(u, M / Mt, e), uv.y / max(h, 1e-4));
  vec4 img = getFromColor(clamp(leftward ? vec2(1.0 - src.x, src.y) : src, 0.0, 1.0));

  float steep = clamp(-dhs * drain * 1.5, 0.0, 1.0);
  float lit = clamp(slope * 2.5 + 0.6, 0.0, 1.0);
  float dd = max(d, 0.0);
  float near = exp(-dd / 0.08);
  img.rgb *= 1.0 - moving * (0.3 * (1.0 - src.y) + 0.2 * steep) - 0.25 * moving * near * (1.0 - lit);

  float fast = min(moving * 2.0, 1.0);
  vec2 fq = vec2((x - 0.9 * t) * 16.0, d * 30.0);
  float froth = vnoise(fq) * 0.6 + vnoise(fq * vec2(2.3, 2.7) + 5.1) * 0.4;
  float foamDepth = (0.006 + 0.05 * fast) * (0.5 + froth);
  float fm = foam * fast * smoothstep(0.0, 0.003, d) * (1.0 - smoothstep(0.6, 1.0, d / foamDepth));
  fm *= smoothstep(0.25, 0.55, froth + 0.3 * fast - 0.15);
  img.rgb = mix(img.rgb, vec3(0.94, 0.97, 1.0), fm);

  float streak = 0.5 + 0.5 * vnoise(vec2((x - 1.2 * t) * 8.0, 0.5));
  float spec = gloss * fast * (0.2 + 0.8 * lit) * streak;
  float band = exp(-abs(d - 0.03 - 0.03 * fast) / 0.012);
  img.rgb += spec * (0.8 * exp(-dd / 0.008) * smoothstep(0.0, 0.003, d) + 0.35 * band * (1.0 - fm) + 0.1 * near);
  img.rgb = min(img.rgb, 1.0);

  vec4 bg = getToColor(uv);
  float above = -d;
  float shadow = exp(-max(above, 0.0) / 0.05) * smoothstep(-0.002, 0.0, above) * min(moving * 3.0, 1.0);
  bg.rgb *= 1.0 - 0.35 * shadow * smoothstep(0.0, 0.3, drain) * smoothstep(0.0, 0.05, t);
  return mix(bg, img, inside);
}
