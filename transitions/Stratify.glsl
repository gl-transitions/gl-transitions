// Author: gre
// License: MIT
// Description: The outgoing image separates by its own brightness like oil and water: its light shapes float up out of the frame as one cut-out layer while its dark shapes sink down as another, both keeping their outlines and casting soft shadows, revealing the incoming image between them
// Tags: content, luma, split, layers, vertical, shadow

// @range(0, 1) Shadow strength
uniform float shadow; // = 0.5
// @range(0, 0.1) Softness of the light and dark outlines
uniform float softness; // = 0.04

const vec3 W = vec3(0.299, 0.587, 0.114);

float luma(vec2 p) {
  return dot(getFromColor(p).rgb, W);
}

// pixel-isotropic offset, in parts of the shorter side
vec2 unit(float r) {
  return vec2(r / max(ratio, 1.0), r * min(ratio, 1.0));
}

// an odd tap count: no two taps lie on one line through p, so a thin line never counts twice
float around(vec2 p) {
  vec2 d = unit(0.05);
  float sum = 0.0;
  for (int i = 0; i < 5; i++) {
    float a = 1.2566 * float(i) + 0.3;
    vec2 q = p + d * vec2(cos(a), sin(a));
    sum += luma(1.0 - abs(1.0 - mod(q, 2.0)));
  }
  return 0.2 * sum;
}

// the pixel draws the outline, its surroundings pick the layer, so thin bright details stay with the dark one;
// a flat area at the threshold goes whole to the dark one instead of splitting into two ghosts
float lightness(vec2 p, vec4 c, float th, float soft) {
  return smoothstep(th - soft, th + soft + 1e-4, dot(c.rgb, W)) * smoothstep(th, th + 0.08, around(p));
}

float inside(float y, float aa) {
  return clamp(min(y, 1.0 - y) / aa + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  float th = 0.25 * (luma(vec2(0.25)) + luma(vec2(0.75)) + luma(vec2(0.25, 0.75)) + luma(vec2(0.75, 0.25)));
  th = clamp(th, 0.1, 0.9);

  float t = progress;
  float rise = 1.08 * t * t * (1.6 - 0.6 * t);
  float sink = 1.08 * t * t * t * (2.0 - t);
  float lift = sin(3.14159 * t);
  float aa = 0.0015 * smoothstep(0.0, 0.1, t) + 1e-6;

  vec2 pL = uv - vec2(0.0, rise);
  vec2 pD = uv + vec2(0.0, sink);
  vec4 light = getFromColor(pL);
  vec4 dark = getFromColor(pD);
  float mL = inside(pL.y, aa) * lightness(pL, light, th, softness);
  float mD = inside(pD.y, aa) * (1.0 - lightness(pD, dark, th, softness));
  float wD = min(mD, 1.0 - mL);

  vec2 so = unit(1.0) * vec2(-0.012, 0.02) * lift;
  vec2 sL = pL + so;
  vec2 sD = pD + so;
  float shL = inside(sL.y, aa) * lightness(sL, getFromColor(sL), th, 0.1);
  float shD = inside(sD.y, aa) * (1.0 - lightness(sD, getFromColor(sD), th, 0.1));

  vec4 to = getToColor(uv);
  to.rgb *= 1.0 - shadow * lift * max(shL, shD);
  // the light layer floats above the dark one
  dark.rgb *= 1.0 - shadow * lift * shL;
  return to * (1.0 - mL - wD) + dark * wD + light * mL;
}
