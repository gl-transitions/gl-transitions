// Author: gre
// License: MIT
// Description: Straight cuts are scored across the outgoing image one after another, and each time the piece beyond the cut lifts and slides away along it, whittling the image down to a small polygon that slides off last and uncovers the incoming image
// Tags: cut, slice, slide, shadow

// @range(2, 6, 1) Number of cuts before the last piece slides away
uniform int cuts; // = 5
// @color Color of the score line drawn along each cut (alpha sets the intensity)
uniform vec4 score; // = vec4(1.0, 0.97, 0.9, 0.85)
// @color Color of the shadow the lifted pieces cast on the incoming image
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.45)

const float AA = 0.0018;
const float SCORE_TIME = 0.075;
const float LIFT = 0.025;
const float GAP = 0.012;
const vec2 SHADOW_OFFSET = vec2(0.014, -0.022);
const float SHADOW_BLUR = 0.03;

// golden-angle steps spread the cut directions evenly whatever their number
vec2 normalOf(float k) {
  float a = k * 2.39996 + 0.7;
  return vec2(cos(a), sin(a));
}

// offsets shrink so every cut still crosses what is left
float offsetOf(float k, float n, float r) {
  return 0.42 * r * (0.35 + 0.65 * (1.0 - k / n)) * (0.8 + 0.2 * fract(k * 0.618));
}

float boxDistance(vec2 q) {
  vec2 d = abs(q) - 0.5 * vec2(ratio, 1.0);
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// signed distance to piece k (q relative to the center), negative inside; piece nc is the last polygon
float pieceDistance(vec2 q, int k, int nc, float n, float r) {
  float sd = boxDistance(q);
  for (int m = 0; m < 6; m++) {
    if (m >= k) break;
    float fm = float(m);
    sd = max(sd, dot(q, normalOf(fm)) - offsetOf(fm, n, r));
  }
  if (k < nc) sd = max(sd, offsetOf(float(k), n, r) - dot(q, normalOf(float(k))));
  return sd;
}

vec2 slideDir(float k, vec2 nk) {
  return vec2(-nk.y, nk.x) * (mod(k, 2.0) < 0.5 ? 1.0 : -1.0);
}

float startOf(float k, float n) {
  return 0.08 + k * 0.92 / (n + 2.2);
}

float slideOf(float k, float n) {
  return clamp((progress - startOf(k, n)) * (n + 2.2) / (0.92 * 2.2), 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec2 P = (uv - 0.5) * vec2(ratio, 1.0);
  int nc = int(clamp(float(cuts), 2.0, 6.0));
  float n = float(nc);
  float r = min(ratio, 1.0) + 0.25 * abs(ratio - 1.0);
  // just enough to clear the frame with the shadow, so the slide never runs off-screen for long
  float travel = length(vec2(ratio, 1.0)) + 0.1;

  vec4 c = getToColor(uv);
  for (int k = 6; k >= 0; k--) {
    if (k > nc) continue;
    float fk = float(k);
    bool last = k == nc;
    vec2 nk = normalOf(last ? fk - 1.0 : fk);
    vec2 dk = slideDir(fk, nk);
    float g = slideOf(fk, n);
    if (g >= 1.0) continue;
    float lift = smoothstep(0.0, 0.35, g);
    vec2 shift = dk * travel * g * g * g + (last ? vec2(0.0) : nk * GAP * lift);
    float scale = 1.0 + LIFT * lift * (1.0 - g);
    vec2 Q = (P - shift) / scale;
    vec2 S = (P - shift - SHADOW_OFFSET * lift) / scale;
    if (lift > 0.0) {
      float blur = SHADOW_BLUR * (0.3 + lift);
      float sh = lift * (1.0 - smoothstep(-blur, blur, pieceDistance(S, k, nc, n, r)));
      c.rgb = mix(c.rgb, shadow.rgb, shadow.a * sh);
    }

    // overhang by AA: while pieces still touch, overlapping edges sample the same pixel
    float cover = clamp(0.5 - (pieceDistance(Q, k, nc, n, r) - AA) / AA, 0.0, 1.0);
    if (cover <= 0.0) continue;
    vec4 col = getFromColor(clamp(Q / vec2(ratio, 1.0) + 0.5, 0.0, 1.0));
    for (int m = 0; m < 6; m++) {
      if (m > k || m >= nc) break;
      float fm = float(m);
      vec2 nm = normalOf(fm);
      vec2 dm = slideDir(fm, nm);
      float run = clamp((progress - startOf(fm, n) + SCORE_TIME) / SCORE_TIME, 0.0, 1.0);
      float head = mix(-1.0, 1.0, run) * (0.5 * dot(abs(dm), vec2(ratio, 1.0)) + 0.02);
      float behind = head - dot(Q, dm);
      float drawn = clamp(0.5 + behind / AA, 0.0, 1.0) * (1.0 - smoothstep(0.0, 0.25, slideOf(fm, n)));
      float e = abs(dot(Q, nm) - offsetOf(fm, n, r));
      float line = exp(-e / 0.0016) + 0.3 * exp(-e / 0.008);
      float tip = exp(-length(vec2(behind, e)) / 0.012) * min(run * 20.0, 1.0) * (1.0 - run);
      col.rgb = mix(col.rgb, score.rgb, clamp(score.a * drawn * (line * (0.6 + 0.4 * exp(-max(behind, 0.0) * 3.0)) + tip), 0.0, 1.0));
    }
    c = mix(c, col, cover);
  }
  return c;
}
