// Author: gre
// License: MIT
// Description: The outgoing image is pulled apart down the middle like melted cheese: the halves part slowly while the picture between them stretches into a gooey web, which opens into glossy strings that thin out, sag and snap one by one, until the halves slide off and leave the incoming image
// Tags: split, sticky, organic, horizontal, stretch

// @range(4, 32, 1) Number of strings across the height of the frame
uniform float strings; // = 20.0
// @range(0, 1) How much the strings sag under their weight
uniform float sag; // = 0.7
// @range(0, 1) Strength of the shading, glossy highlight and shadow of the strings
uniform float gloss; // = 0.7
// @param Random seed: another value gives other strings
uniform float seed; // = 0.0

const float AA = 0.002;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float mirror(float v) {
  return 1.0 - abs(1.0 - abs(v));
}

vec4 transition(vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  float x0 = 0.5 * ratio + 0.012 * sin(q.y * 7.0 + 1.0) + 0.006 * sin(q.y * 19.0 + 2.0);
  // slow while the goo holds, then the halves let go and slide off
  float D = 0.5 * ratio + 0.06;
  float p = progress;
  float d = D * p * (0.45 + 0.55 * p * p);
  float G = d / D;
  float H = min(q.x - x0 + d, x0 + d - q.x);
  float on = smoothstep(0.0, 0.03, G);
  if (H < 0.0) {
    vec2 h = q.x < x0 ? q + vec2(d, 0.0) : q - vec2(d, 0.0);
    vec4 c = getFromColor(vec2(h.x / ratio, h.y));
    c.rgb *= 1.0 - 0.2 * gloss * on * (1.0 - smoothstep(0.0, 0.015, -H));
    return c;
  }
  float s = clamp((q.x - x0) / max(d, 1e-5), -1.0, 1.0);
  float n = max(strings, 1.0);
  float fade = 1.0 - smoothstep(0.85, 0.98, p);
  float best = -1.0;
  float bestN = 0.0;
  float bestW = 1.0;
  float bestOff = 0.0;
  float cov = 0.0;
  float shade = 0.0;
  for (int i = 0; i < 32; i++) {
    float fi = float(i);
    if (fi >= n) break;
    vec2 o = vec2(fi, 7.3 * seed);
    float h1 = hash(o + 1.7);
    float h2 = hash(o + 2.9);
    float h3 = hash(o + 4.1);
    float h4 = hash(o + 5.3);
    float h5 = hash(o + 6.7);
    float h6 = hash(o + 8.3);
    float yL = (fi + 0.5 + 0.9 * (h1 - 0.5)) / n;
    float st = smoothstep(0.12 + 0.1 * h3, 0.4 + 0.12 * h5, p);
    float yR = yL + (h2 - 0.5) * 3.5 / n * st;
    float hang = sag * (0.1 + 0.9 * h3 * h3) * 0.45 * G;
    // thick strings hold on longest
    float ts = 0.45 + 0.2 * h4 + 0.2 * h6;
    float k = smoothstep(ts, ts + 0.05, p);
    float sb = 0.7 * (h5 - 0.5);
    float side = s < sb ? -1.0 : 1.0;
    float a = (1.0 - side * s) * d;
    float aTip = mix((1.0 - side * sb) * d, 0.035 + 0.03 * h1, k);
    float lineY = mix(yL, yR, 0.5 * s + 0.5);
    float yc = lineY - hang * (1.0 - s * s) * (1.0 - k) - k * sag * 1.5 * a * a;
    float slope = (0.5 * (yR - yL) + 2.0 * hang * s * (1.0 - k)) / max(d, 1e-4) + 3.0 * k * sag * a * side;
    float dist = abs(q.y - yc) / sqrt(1.0 + slope * slope);
    float hw = mix(0.9 / n, mix(0.008, 0.03, h6 * h6) * 0.35 / (0.35 + d), st);
    hw *= mix(1.0, 0.6 + 0.4 * s * s, st) * (0.8 + 0.4 * sin(s * (4.0 + 5.0 * h2) + 6.28 * h4));
    hw *= 1.0 - 0.7 * smoothstep(ts - 0.08, ts, p) * exp(-(s - sb) * (s - sb) * 30.0);
    hw += 0.6 / n * exp(-(1.0 - abs(s)) * d / 0.025);
    hw *= fade * mix(1.0, smoothstep(0.0, 0.025, aTip - a), k);
    float m = hw - dist;
    if (m > best) {
      best = m;
      bestN = q.y - yc;
      bestW = hw;
      bestOff = yc - lineY;
    }
    float fat = clamp(hw / AA, 0.0, 1.0);
    cov = max(cov, smoothstep(-AA, AA, m) * fat);
    shade = max(shade, smoothstep(-0.008, 0.004, hw - abs(q.y + 0.01 - yc)) * fat);
  }
  vec4 c = getFromColor(vec2(x0 / ratio, mirror(q.y - bestOff)));
  // flat inside the web, round near its edges and across thin strings
  float body = clamp(best / max(min(bestW, 0.01), 1e-5), 0.0, 1.0);
  float nn = sign(bestN) * (1.0 - body);
  float g = gloss * on;
  c.rgb *= 1.0 - g * 0.35 * (1.0 - sqrt(1.0 - nn * nn));
  c.rgb += g * 0.45 * exp(-(nn - 0.5) * (nn - 0.5) * 40.0) * c.a;
  vec4 inc = getToColor(uv);
  inc.rgb *= 1.0 - 0.4 * g * shade - 0.25 * g * fade * exp(-H / 0.012);
  float w = mix(1.0, cov, smoothstep(0.0, 2.0 * AA, 2.0 * d));
  return mix(inc, c, w);
}
