// Author: gre
// License: MIT
// Description: Firework shells burst one after another over the outgoing picture, each into a sphere of colored sparks whose trails droop under gravity; every trail is a streak of the incoming picture that widens behind its spark until the bursts fill the frame with it
// Tags: fireworks, sparks, burst, night, celebration, reveal

// @range(0.5, 2) Size of the bursts
uniform float burstSize; // = 1.0
// @range(0, 1) How far the trails droop under gravity
uniform float droop; // = 0.5

const float PI = 3.141592653589793;
const float SPOKES = 34.0;

float hash11(float n) {
  vec2 p = fract(vec2(n) * vec2(0.1031, 0.1103));
  p += dot(p, p.yx + 33.33);
  return fract((p.x + p.y) * p.y);
}

// time a spark with drag takes to travel r out of a range R
float tauOf(float r, float R) {
  float x = 1.0 - 0.982 * r / R;
  return x > 0.018 ? -log(x) / 4.0 : 99.0;
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float cover = 0.0;
  vec3 tint = vec3(0.0);
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float start = 0.02 + fi * 0.125;
    float t = (progress - start) / 0.36;
    bool last = i == 5;
    vec2 c = last ? vec2(0.5 * ratio, 0.62) : vec2((0.12 + 0.76 * hash11(fi * 7.1 + 1.0)) * ratio, 0.42 + 0.4 * hash11(fi * 3.7 + 9.0));
    float R = burstSize * (0.42 + 0.2 * hash11(fi * 5.3 + 4.0)) * max(ratio, 1.0) * (last ? 1.6 : 1.0);
    if (t > 0.0 && length(q - c) < R * 1.25 + droop * 0.5) {
      vec2 d = q - c;
      float offset = hash11(fi) * 10.0 + 0.5;
      float tau = 0.0;
      vec2 dd = d;
      float spoke = 0.0;
      for (int k = 0; k < 2; k++) {
        dd = d + vec2(0.0, droop * 0.45 * min(tau, 2.0) * tau);
        // atan only picks the spoke, between spokes; mod wraps its +-PI seam
        spoke = floor(atan(dd.y, dd.x) / (2.0 * PI) * SPOKES + offset + 0.5);
        tau = tauOf(length(dd), R * (0.8 + 0.2 * hash11(mod(spoke, SPOKES) * 1.7 + fi * 13.0)));
      }
      float age = t - tau;
      // the distance to the spoke's axis comes from a cross product: atan is too approximate on some targets
      float th = (spoke - offset) * 2.0 * PI / SPOKES;
      float side = abs(cos(th) * dd.y - sin(th) * dd.x) / max(length(dd), 1e-4);
      float da = 1.0 - side * SPOKES / PI;
      float width = mix(0.12, 1.08, smoothstep(0.1, 1.0, age));
      float aa = SPOKES * 0.004 / (2.0 * PI * max(length(dd), 0.01)) + 0.04;
      float streak = (1.0 - smoothstep(width - aa, width + aa, 1.0 - da)) * step(0.0, age);
      cover = max(cover, streak);
      vec3 hue = 0.6 + 0.4 * cos(6.283 * (hash11(fi * 2.9) + vec3(0.0, 0.33, 0.67)));
      float hot = streak * exp(-max(age, 0.0) * 7.0) * (1.0 - smoothstep(0.6, 1.2, t));
      float head = exp(-age * age * 900.0) * smoothstep(0.0, 0.35, da) * step(0.0, age);
      float flash = exp(-length(d) * 9.0 / burstSize) * exp(-t * 18.0) * 2.5 * (1.0 - cover);
      tint += (hot + head * 1.5 + flash) * (1.0 - progress) * hue;
    }
  }
  cover = max(cover, smoothstep(0.86, 1.0, progress));
  float night = 1.0 - 0.35 * sin(PI * progress);
  vec4 from = getFromColor(uv);
  vec4 col = mix(vec4(from.rgb * night, from.a), getToColor(uv), cover);
  return vec4(min(col.rgb + tint * 0.8, 1.0), col.a);
}
