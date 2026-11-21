// Author: gre
// License: MIT
// Description: The outgoing picture beads up into a glossy drop resting on a pool of the incoming picture; it drains into the pool with a ring of ripples but leaves a smaller drop that hops up and lands a little further on, again and again, until the last drop melts into the pool
// Tags: liquid, drop, ripple, bounce, organic

// @range(2, 5, 1) Number of drains before the drop is gone
uniform float steps; // = 4.0
// @range(0, 1) Strength of the gloss, shadow and ripples
uniform float gloss; // = 0.8

const float PI = 3.14159265;
// each hop leaves a drop this much smaller, so the last ones stay readable
const float SHRINK = 0.65;

float sdBox(vec2 p, vec2 h, float r) {
  vec2 q = abs(p) - h + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float stageEnd(float k, float n) {
  // smaller drops drain faster
  return 0.94 * (1.0 - pow(max(1.0 - k / n, 0.0), 1.4));
}

// where the drop k lands, kept inside the frame with its swell
vec2 spot(float k, float rr, float r0) {
  vec2 c = vec2(0.3 * rr * cos(2.2 * k + 0.6), 0.16 * sin(2.2 * k + 0.6)) * (1.0 - 0.1 * k);
  float xmax = max(0.5 * ratio - 1.3 * r0 * pow(SHRINK, k), 0.0);
  return k < 0.5 ? vec2(0.0) : vec2(clamp(c.x, -xmax, xmax), c.y);
}

vec2 mirrored(vec2 v) {
  return 1.0 - abs(1.0 - abs(v));
}

vec4 transition(vec2 uv) {
  float n = floor(clamp(steps, 2.0, 5.0));
  vec2 frame = vec2(ratio, 1.0) * 0.5;
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float aa = 1.5 / 200.0;
  float rr = min(ratio, 1.0);
  float r0 = 0.45 * rr;

  float s = 1.0, rnd = 0.0, hgt = 0.0, fade = 0.0;
  vec2 c = vec2(0.0);
  vec2 ripple = vec2(0.0);
  float glint = 0.0;
  for (int i = 0; i < 5; i++) {
    float k = float(i);
    if (k >= n) break;
    float t0 = stageEnd(k, n), t1 = stageEnd(k + 1.0, n);
    float t = clamp((progress - t0) / (t1 - t0), 0.0, 1.0);
    bool last = k + 1.0 >= n;
    float s0 = pow(SHRINK, k), s1 = s0 * SHRINK;
    vec2 c0 = spot(k, rr, r0), c1 = spot(k + 1.0, rr, r0);
    float drain = smoothstep(i == 0 ? 0.36 : 0.15, 0.58, t);
    float v = smoothstep(0.55, 1.0, t);
    if (progress >= t0) {
      float dip = 1.0 - 0.3 * sin(PI * clamp((t - 0.35) / 0.25, 0.0, 1.0));
      if (last) {
        // the last drop spreads out as it melts instead of shrinking away
        float melt = smoothstep(0.3, 0.9, t);
        s = s0 * (1.0 + 0.35 * melt) * mix(dip, 1.0, melt);
        fade = melt;
        hgt = 0.0;
        c = c0;
      } else {
        float h = sin(PI * v);
        s = mix(s0, s1, drain * drain) * dip * (1.0 + 0.3 * h);
        hgt = h * s1 * 2.0;
        c = mix(c0, c1, v);
      }
      if (i == 0) rnd = smoothstep(0.0, 0.4, t);
    }
    float age = progress - mix(t0, t1, last ? 0.6 : 0.5);
    float d = length(p - c0) - (s0 * r0 * 0.9 + age * 0.9);
    float amp = 0.03 * sqrt(s0) * smoothstep(0.0, 0.03, age) * exp(-age * 4.0) * min(1.0, 8.0 * (1.0 - progress));
    float env = exp(-d * d / 0.003);
    ripple += normalize(p - c0 + 1e-5) * amp * env * sin(d * 60.0);
    glint += amp * 12.0 * env * cos(d * 60.0);
  }

  vec2 hb = s * mix(frame + 3.0 * aa, vec2(r0), rnd) - 2.0 * aa;
  float cr = rnd * min(hb.x, hb.y);
  vec2 lp = p - c;
  float sd = sdBox(lp, hb, cr);
  float inside = smoothstep(aa, -aa, sd) * (1.0 - fade);

  vec4 pool = getToColor(mirrored(uv + ripple * gloss / vec2(ratio, 1.0)));
  pool.rgb *= 1.0 + glint * gloss;
  vec2 sp = lp - vec2(0.12, -0.16) * (hgt + 0.08 * s * rnd);
  float ssd = sdBox(sp, hb, cr);
  float soft = 0.02 + 0.06 * hgt;
  pool.rgb *= 1.0 - 0.45 * gloss * rnd * (1.0 - fade) * smoothstep(soft, -soft, ssd) / (1.0 + 3.0 * hgt);

  vec4 col = getFromColor(clamp(lp / max(s, 1e-3) / vec2(ratio, 1.0) + 0.5, 0.0, 1.0));
  float rim = 0.07 * max(s, 0.15);
  float h = clamp(-sd / rim, 0.0, 1.0);
  float edge = (1.0 - sqrt(1.0 - (1.0 - h) * (1.0 - h))) * rnd;
  float lit = dot(normalize(lp + 1e-5), normalize(vec2(-0.6, 0.8)));
  col.rgb *= 1.0 - 0.45 * gloss * edge * (0.6 - 0.4 * lit);
  col.rgb += gloss * edge * smoothstep(0.4, 1.0, lit) * 0.6;
  vec2 hp = (lp - hb * vec2(-0.45, 0.45)) / max(min(hb.x, hb.y), 1e-3);
  col.rgb += gloss * rnd * 0.5 * (1.0 - smoothstep(0.0, 0.35, length(hp) * 2.5));
  return mix(pool, col, inside);
}
