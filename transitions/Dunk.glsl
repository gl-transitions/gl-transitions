// Author: gre
// License: MIT
// Description: The outgoing picture is dunked like a biscuit into coffee: the coffee wicks up from the bottom edge, racing through its light areas and creeping around its dark shapes behind a brown tide line, and the soaked part shows the incoming picture stained brown, clearing as it settles
// Tags: liquid, coffee, wick, organic, image-driven

// @range(0, 1) How much the outgoing picture's dark shapes hold the coffee back
uniform float hold; // = 0.8
// @range(0, 1) How strongly the soaked part is stained behind the front
uniform float stain; // = 0.85
// @color Color of the coffee stain and tide line (its alpha is its strength)
uniform vec4 coffee; // = vec4(0.45, 0.27, 0.13, 1.0)

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
  vec2 R = vec2(ratio, 1.0);
  vec2 P = uv * R;
  // darkness in a cone below the pixel, where its coffee comes from; shifted (never stretched) taps avoid vertical streaks
  float slow = 0.0, wsum = 0.0;
  for (int k = 0; k < 12; k++) {
    float t = (float(k) + 0.5) / 12.0;
    vec2 q = P + vec2((fract(float(k) * 0.618) - 0.5) * (0.12 + 0.5 * t), -0.4 * t);
    float wk = 1.5 - t;
    slow += wk * (1.0 - luma(getFromColor(1.0 - abs(1.0 - abs(q / R))).rgb));
    wsum += wk;
  }
  slow /= wsum;
  // relative to the picture's mean darkness, so dark and light pictures climb at the same pace
  float g = 0.0;
  for (int k = 0; k < 9; k++) {
    vec2 c = (vec2(mod(float(k), 3.0), floor(float(k) / 3.0)) + 0.5) / 3.0;
    g += 1.0 - luma(getFromColor(c).rgb);
  }
  g /= 9.0;
  float rough = 0.08 * (noise(P * 5.0) + 0.5 * noise(P * 19.0) + 0.3 * noise(P * 47.0) - 0.9);
  float h = clamp(uv.y + rough, 1e-4, 1.0);
  float e = exp(-3.2 * hold * clamp(slow - g, -0.5, 0.5) * smoothstep(0.0, 0.35, uv.y));
  // a power of the height stays in 0..1, so dark areas arrive later yet still by the end
  float A = pow(h, e);
  float front = 1.02 * (1.0 - pow(1.0 - progress, 1.6));
  // distance behind the front in frame heights (A over its slope), so edges keep one width on screen
  float s = (front - A) * h / max(e * A, 1e-6);
  float wet = smoothstep(0.0, 0.004, s);
  float age = clamp(s / 0.6, 0.0, 1.0);
  float fade = 1.0 - progress * progress * progress;

  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec3 tone = coffee.rgb / max(max(coffee.r, coffee.g), max(coffee.b, 0.01));
  float damp = (1.0 - smoothstep(0.0, 0.05, -s)) * (1.0 - wet) * min(progress * 12.0, 1.0) * coffee.a;
  vec3 dry = a.rgb * mix(vec3(1.0), tone * 0.75, 0.45 * damp * damp);
  float tint = min(1.0, stain * coffee.a * (1.0 - age * age) * fade * (0.7 + 0.6 * noise(P * 5.0 + 3.0)));
  vec3 sepia = vec3(luma(b.rgb)) * tone + coffee.rgb * 0.15;
  vec3 soaked = mix(b.rgb, mix(b.rgb * tone * 0.9, sepia, 0.6), tint);
  float tide = wet * (1.0 - smoothstep(0.004, 0.03, s)) * fade * coffee.a;
  soaked = mix(soaked, coffee.rgb, 0.8 * tide);
  return vec4(mix(dry, soaked, wet), mix(a.a, b.a, wet));
}
