// Author: gre
// License: MIT
// Description: Warm hands press the outgoing image one after another, each leaving the print of its palm and fingers in the incoming image; the warmth spreads out of the prints until they run together over the whole frame
// Tags: organic, hand, touch, heat, reveal, playful

// @range(0.8, 2.0) Size of the hands
uniform float size; // = 1.35
// @color Glow of the warm edges (alpha is its strength)
uniform vec4 warmth; // = vec4(1.0, 0.4, 0.05, 0.4)

vec3 hash3(vec2 p) {
  vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yxz + 33.33);
  return fract((q.xxy + q.yzz) * q.zyx);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash3(i).x, hash3(i + vec2(1.0, 0.0)).x, f.x), mix(hash3(i + vec2(0.0, 1.0)).x, hash3(i + 1.0).x, f.x), f.y);
}

float finger(vec2 p, vec2 a, vec2 b, float r) {
  p -= a;
  float t = clamp(dot(p, b) / dot(b, b), 0.0, 1.0);
  return length(p - b * t) - r * (1.08 - 0.22 * t);
}

float smin(float a, float b) {
  float h = max(0.03 - abs(a - b), 0.0) / 0.03;
  return min(a, b) - h * h * 0.0075;
}

// the thumb is on the left; pose: how far the fingers spread, how long they are, how open the thumb is
float hand(vec2 p, vec3 pose) {
  vec2 k = vec2(0.6 + 0.6 * pose.x, 0.92 + 0.16 * pose.y);
  float lean = 0.03 * (pose.z - 0.5);
  float f = finger(p, vec2(-0.06, 0.05), vec2(-0.06 + lean, 0.135) * k, 0.023);
  f = min(f, finger(p, vec2(-0.02, 0.06), vec2(-0.018 + lean, 0.185) * k, 0.026));
  f = min(f, finger(p, vec2(0.025, 0.06), vec2(0.022 + lean, 0.18) * k, 0.026));
  f = min(f, finger(p, vec2(0.065, 0.03), vec2(0.06 + lean, 0.135) * k, 0.022));
  f = smin(f, finger(p, vec2(-0.05, -0.08), vec2(-0.125 + 0.03 * pose.y, 0.095 + 0.04 * pose.z), 0.03));
  return smin(f, finger(p, vec2(-0.015, -0.085), vec2(0.03, 0.09), 0.084));
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0), q = (uv - 0.5) * asp;
  float s = size * min(ratio, 1.0);
  float n = noise(q * 7.0) + 0.5 * noise(q * 16.0) - 0.75;
  float flood = clamp((p - 0.4) / 0.6, 0.0, 1.0);
  // the last corners are reached by the spreading front rather than faded
  flood *= flood * (0.27 * max(asp.x, asp.y) + 0.25 * max(1.2 - s, 0.0));
  float cold = 1.0, halo = 0.0, hot = 0.0, press = 0.0;
  for (int i = 0; i < 9; i++) {
    float fi = float(i);
    float age = (p - 0.02 - 0.062 * fi) / 0.1;
    if (age <= 0.0) continue;
    vec3 h = hash3(vec2(fi, 3.0));
    vec2 c = (fract(vec2(0.7549, 0.5698) * fi + vec2(0.37, 0.47)) - 0.5) * asp * vec2(0.92, 0.76) - vec2(0.0, 0.03 * s);
    vec2 d = (q - c) / s;
    float old = max(age - 1.6, 0.0);
    float spread = 0.004 * old * old + flood - 0.011 * s * exp(-6.0 * age);
    if ((length(d) - 0.34) * s - spread > 0.4) continue;
    float an = (h.x - 0.5) * 1.1 - 0.25 * c.x / max(ratio, 1.0);
    d = vec2(d.x * cos(an) + d.y * sin(an), d.y * cos(an) - d.x * sin(an));
    // mostly left hands on the left side and right hands on the right
    d.x *= c.x / ratio < 0.3 * (h.y - 0.5) ? -1.0 : 1.0;
    float f = hand(d, h.yzx) * s;
    float on = smoothstep(0.0, 0.55, age);
    float edge = f - spread + 0.037 * s * n * min(old, 1.0);
    float w = s * (0.006 + 0.0045 * min(old, 2.5));
    float g = on / (1.0 + exp(clamp(edge / w, -20.0, 20.0)));
    cold *= 1.0 - g;
    halo = max(halo, on * exp(-max(edge, 0.0) / (0.026 * s)) * (0.35 + 0.65 * exp(-0.8 * age)));
    hot = max(hot, g * exp(-0.7 * age));
    press = max(press, (1.0 - smoothstep(0.0, 0.034 * s, f)) * smoothstep(0.1, 0.5, age) * (1.0 - smoothstep(0.5, 1.4, age)));
  }
  float m = smoothstep(0.25, 0.75, 1.0 - cold);
  vec4 a = getFromColor(uv), b = getToColor(uv);
  vec4 o = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  o.rgb *= 1.0 - 0.3 * press * (1.0 - m);
  float calm = 1.0 - smoothstep(0.8, 1.0, p);
  float glow = 2.6 * m * (1.0 - m) + 0.55 * halo * (1.0 - m) + 0.45 * hot * m * calm;
  o.rgb += o.a * warmth.a * glow * warmth.rgb;
  return o.a > 0.0 ? vec4(min(o.rgb / o.a, 1.0), o.a) : vec4(0.0);
}
