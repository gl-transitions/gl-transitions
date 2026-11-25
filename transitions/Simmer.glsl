// Author: gre
// License: MIT
// Description: The outgoing picture comes to the boil like thick hot paint: glossy domes swell all over it and burst with a crater, a ring and a little jet, and each burst lets the incoming picture spill out and spread until the surface settles
// Tags: liquid, boil, bubbles, glossy, 3d
// Preview: 0.4

// @range(3, 9) Bubbles across the height of the frame
uniform float density; // = 3.6
// @range(0, 1) Strength of the wet highlights
uniform float gloss; // = 0.7

vec2 hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x), mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0, 1.0)).x, f.x), f.y);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

const int ROUNDS = 3;
// how far around a point the slope is measured, in cells
const float SLOPE = 0.018;

// x: height of the surface, y: spread of the incoming liquid, zw: slope of the surface
vec4 simmer(vec2 w, float reveal, float ramp) {
  float h = 0.0;
  // right, left, up and down of w: they share the bubbles of w, each with its own 3x3 cells
  vec4 hs = vec4(0.0);
  float cov = 0.0;
  for (int k = 0; k < ROUNDS; k++) {
    float fk = float(k);
    // no bubble of this round was born yet
    if (0.86 * progress <= 0.01 + 0.13 * fk) {
      h = max(h, 0.0);
      hs = max(hs, 0.0);
      break;
    }
    vec2 v = w + fk * vec2(0.37, 0.61);
    vec2 i = floor(v);
    vec4 ix = floor(v.x + SLOPE * vec4(1.0, -1.0, 0.0, 0.0)) - i.x;
    vec4 iy = floor(v.y + SLOPE * vec4(0.0, 0.0, 1.0, -1.0)) - i.y;
    vec2 first = vec2(min(ix.y, 0.0), min(iy.w, 0.0)) - 1.0;
    vec2 last = vec2(max(ix.x, 0.0), max(iy.z, 0.0)) + 1.0;
    for (int y = 0; y < 4; y++) {
      for (int x = 0; x < 4; x++) {
        vec2 o = first + vec2(float(x), float(y));
        if (o.x > last.x || o.y > last.y) continue;
        float on = step(max(abs(o.x), abs(o.y)), 1.0);
        vec4 ons = step(max(abs(o.x - ix), abs(o.y - iy)), vec4(1.0));
        vec2 c = i + o;
        float born = 0.01 + 0.13 * fk + 0.26 * hash2(c + 3.0 + 5.0 * fk).y;
        float grow = clamp((0.86 * progress - born) / 0.16, 0.0, 1.0);
        float t = 0.86 * progress - born - 0.16;
        if (t < 0.0) {
          h = mix(h, max(h, 0.0), on);
          hs = mix(hs, max(hs, 0.0), ons);
        }
        if (grow <= 0.0) continue;
        // once its ring is gone, a burst only spreads the incoming liquid, up to where it covers all
        if (t > 0.2 && (on < 0.5 || cov * reveal + ramp > 0.56)) continue;
        vec2 d = v - c - 0.2 - 0.6 * hash2(c + 31.0 * fk);
        float l2 = dot(d, d);
        float l = sqrt(l2);
        if (t < 0.0 && l > 0.94) continue;
        float s = hash2(c + 7.0 + 13.0 * fk).x;
        float R = mix(0.24, 0.56, s) * (fk > 1.5 ? 0.8 : 1.0);
        vec4 l2s = max(l2 + 2.0 * SLOPE * vec4(d.x, -d.x, d.y, -d.y) + SLOPE * SLOPE, 0.0);
        if (t < 0.0) {
          float rad = R * sqrt(grow);
          if (l > rad * 1.1 + 0.32) continue;
          vec4 ls = sqrt(l2s);
          float z = max(1.0 - l2 / max(rad * rad, 1e-4), 0.0);
          vec4 zs = max(1.0 - l2s / max(rad * rad, 1e-4), 0.0);
          float x1 = (l - rad * 1.1) / 0.08;
          vec4 x1s = (ls - rad * 1.1) / 0.08;
          h = mix(h, max(h, rad * 1.25 * sqrt(z) * smoothstep(0.0, 0.3, z)) + 0.05 * rad * exp(-x1 * x1), on);
          hs = mix(hs, max(hs, rad * 1.25 * sqrt(zs) * smoothstep(0.0, 0.3, zs)) + 0.05 * rad * exp(-x1s * x1s), ons);
        } else {
          cov += on * exp(-l2 / (R * R * (0.35 + 6.5 * t)));
          float u = clamp(t / 0.2, 0.0, 1.0);
          float fade = (1.0 - u) * (1.0 - u);
          float ringR = R * (0.95 + 1.1 * sqrt(u));
          float ringW = 0.1 + 0.1 * u;
          if (fade > 0.0 && l < max(ringR + 3.2 * ringW, 2.2 * R)) {
            float x2 = (l - ringR) / ringW;
            vec4 x2s = (sqrt(l2s) - ringR) / ringW;
            h += on * R * fade * (0.6 * exp(-x2 * x2) - 0.55 * exp(-l2 / (R * R * 0.45)));
            hs += ons * R * fade * (0.6 * exp(-x2s * x2s) - 0.55 * exp(-l2s / (R * R * 0.45)));
          }
          float jet = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.3, 0.6, u));
          if (jet > 0.0 && l < R) {
            h += on * R * 1.1 * jet * exp(-l2 / (R * R * 0.06));
            hs += ons * R * 1.1 * jet * exp(-l2s / (R * R * 0.06));
          }
        }
      }
    }
  }
  return vec4(h, cov, (hs.xz - hs.yw) / (2.0 * SLOPE));
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float g = smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.8, 1.0, p));
  vec2 w = q * density;
  w += 0.12 * g * (vec2(noise(w * 1.7 + p * 5.0), noise(w * 1.7 - p * 5.0 + 9.0)) - 0.5);
  float reveal = smoothstep(0.0, 0.1, p);
  float ramp = smoothstep(0.52, 0.86, p) * 1.1;
  vec4 s = simmer(w, reveal, ramp);
  vec2 grad = s.zw;
  grad = grad / (1.0 + 0.25 * length(grad));
  vec3 n = normalize(vec3(-grad * g, 1.0));

  float m = smoothstep(0.44, 0.56, s.y * reveal + ramp);
  vec2 bend = -n.xy * 0.22 / density * g;
  vec2 st = mirror((q + bend * 0.6) / asp + 0.5);
  vec4 a = getFromColor(st), b = getToColor(st);
  vec4 col = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);

  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
  float win = smoothstep(0.35, 0.55, r.y) * (1.0 - smoothstep(0.8, 0.98, r.y)) * smoothstep(-0.95, -0.8, r.x) * (1.0 - smoothstep(0.0, 0.12, r.x));
  float rim = smoothstep(0.55, 0.95, r.x - 0.5 * r.y);
  vec3 L = normalize(vec3(-0.5, 0.6, 0.75));
  float dif = 0.45 + 0.75 * max(dot(n, L), 0.0);
  vec3 lit = col.rgb * (dif + 0.25 * max(s.x, 0.0)) + gloss * col.a * (0.42 * win + 0.18 * rim * vec3(0.8, 0.9, 1.0));
  // the meniscus between the two liquids
  float seam = m * (1.0 - m) * 4.0;
  lit *= 1.0 - 0.25 * seam;
  col.rgb = mix(col.rgb, lit, g);
  return col.a > 0.0 ? vec4(min(col.rgb / col.a, 1.0), col.a) : vec4(0.0);
}
