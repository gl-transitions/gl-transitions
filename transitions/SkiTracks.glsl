// Author: gre
// License: MIT
// Description: A row of unseen skiers drops into the outgoing picture from the top and carves linked S-turns down it, throwing up puffs of powder at every turn; each carve cuts a groove with a bright snow lip and the incoming picture at its bottom, and the tracks widen as they age until the whole slope is tracked out
// Tags: snow, sport, organic, reveal

// @range(0.12, 0.4) Spacing between the skiers, in frame heights
uniform float spacing; // = 0.26
// @range(0.0, 1.0) Amount of powder thrown up by the skiers
uniform float powder; // = 0.8
// @color Color of the snow lips and the powder
uniform vec4 snow; // = vec4(0.96, 0.97, 1.0, 1.0)
// @color Color of the shade on the groove walls
uniform vec4 shade; // = vec4(0.55, 0.64, 0.82, 1.0)

float stHash(float n) {
  return fract(fract(n * 0.1031) * fract(n * 0.1031 + 33.33) * 47.53);
}

float stNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  float n = i.x + i.y * 57.0;
  return mix(mix(stHash(n), stHash(n + 1.0), f.x), mix(stHash(n + 57.0), stHash(n + 58.0), f.x), f.y);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 q = vec2(uv.x * ratio, uv.y);
  float lanes = max(1.0, floor(ratio / spacing + 0.5));
  float s = ratio / lanes;
  float amp = 0.42 * s;
  float wave = 6.2832 / 0.7;
  float v = 3.0;
  // flattens the sine a little: longer traverses, rounder turns
  float kk = 0.6;
  float ka = 1.0 / asin(kk);
  float wEnd = s * 0.54 + amp * 0.15 + smoothstep(0.92, 1.0, p) * s * 0.12;
  float k0 = floor(q.x / s);
  float edge = 9.0;
  float edge2 = 9.0;
  float side = 0.0;
  float spray = 0.0;
  float twin = 0.0;
  for (int i = 0; i < 3; i++) {
    float k = k0 + float(i) - 1.0;
    float delay = 0.04 * stHash(k * 7.3 + 5.0);
    float a = q.y * wave + 0.3 * stHash(k * 3.7 + 11.0);
    float sa = sin(a);
    float f = asin(kk * sa) * ka;
    float slope = amp * wave * kk * cos(a) * ka / sqrt(1.0 - kk * kk * sa * sa);
    float dx = q.x - (k + 0.5 + 0.24 * stHash(k * 5.1 + 2.0) - 0.12) * s - amp * f;
    float d = abs(dx) / sqrt(1.0 + slope * slope);
    // time since the skier passed this height, negative ahead of it
    float tr = p - delay - (1.025 - q.y) / v;
    // normalized so every track reaches its full width exactly at progress 1
    float u = clamp(tr / (tr + 1.0 - p), 0.0, 1.0);
    float w = mix(0.005 + 0.004 * abs(sa), wEnd, u * u);
    // horizontal distance once tracked out, so the strips between parallel tracks narrow evenly
    float dd = tr > 0.0 ? mix(d, abs(dx), u) : length(vec2(d, tr * v));
    float e = dd - w;
    if (e < edge) { edge2 = edge; edge = e; side = sign(dx); } else { edge2 = min(edge2, e); }
    float age = max(tr, 0.0);
    twin = max(twin, (1.0 - smoothstep(0.001, 0.0025, abs(d - w * 0.55))) * exp(-age * 6.0) * step(0.0, tr));
    float outward = dx * sign(sa) - w;
    float fan = smoothstep(0.5, 1.0, abs(sa)) * smoothstep(-0.01, 0.004, outward) * (1.0 - smoothstep(0.0, 0.02 + age * 0.9, outward));
    float tail = 1.0 - smoothstep(0.0, 0.02 + age * 0.7, d);
    // fades before reaching the lanes the loop does not visit
    spray = max(spray, max(fan, tail) * exp(-age * 5.0) * smoothstep(-0.006, 0.0, tr) * (1.0 - smoothstep(0.6 * s, 0.9 * s, abs(dx))));
  }
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float relief = 1.0 - smoothstep(0.62, 1.0, p);
  float grain = stNoise(q * 30.0);
  float puff = grain * 0.4 + stNoise(q * 80.0 - vec2(p * 4.0, -p * 8.0)) * 0.6;
  edge += (grain - 0.5) * 0.016 * relief;
  float aa = 0.0015;
  float cut = 1.0 - smoothstep(-aa, aa, edge);
  float ridge = relief * smoothstep(0.0, 0.015, p);
  // where two grooves overlap, neither one's wall is left standing
  float solo = smoothstep(-aa, aa, edge2) * relief;
  vec3 sh = mix(vec3(1.0), shade.rgb, shade.a);
  float lw = 0.007 * relief;
  float lit = 0.5 + 0.5 * side;
  float wall = (1.0 - smoothstep(0.0, lw + aa, -edge)) * solo;
  vec3 floorCol = mix(b.rgb, b.rgb * sh, 0.85 * (1.0 - smoothstep(0.0, 0.025 * relief + 0.0001, -edge)) * (1.0 - lit) * solo);
  floorCol = mix(floorCol, b.rgb * sh * 0.7, twin * 0.7 * relief);
  floorCol = mix(floorCol, snow.rgb, wall * lit * 0.9);
  float lo = lw * (0.4 + 1.2 * stNoise(q * 90.0));
  float lip = (1.0 - smoothstep(lo - aa, lo + aa, edge)) * ridge;
  vec3 rim = mix(a.rgb, a.rgb * sh, 0.5 * ridge * (1.0 - smoothstep(lo, lo + 0.02, edge)) * lit);
  rim = mix(rim, snow.rgb * mix(vec3(1.0), sh, clamp(0.15 + 0.6 * lit * edge / (lo + 0.0001), 0.0, 1.0)), lip);
  vec4 col = mix(vec4(rim, mix(a.a, snow.a, lip)), vec4(floorCol, mix(b.a, snow.a, wall * lit * 0.9)), cut);
  float dust = 0.95 * relief * powder * smoothstep(0.3, 0.7, spray * (0.4 + puff));
  return mix(col, snow, dust);
}
