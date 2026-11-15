// Author: gre
// License: MIT
// Description: The incoming image is pasted over the outgoing one as a poster, sheet after sheet: each wet sheet drops onto the wall hanging loose from its top edge with a soft shadow, then a brush smooths it on from top to bottom, leaving wrinkles and air bubbles that flatten out and seams that fade as the paste dries
// Tags: paper, poster, panels, wipe, shadow, 3d

// @range(2, 8) Number of poster sheets pasted side by side, from left to right
uniform float sheets; // = 4.0
// @range(0, 1) How wrinkled, blistered and billowing the wet paper is before the brush smooths it flat
uniform float wrinkles; // = 0.6

const float AA = 0.0015;
// length of the bend of a loose sheet just below its pasted part, in frame heights
const float ARC = 0.18;
// the last sheet is brushed on at this progress, then the paste dries until the end
const float END = 0.86;
// each sheet starts this share of a sheet's duration after the previous one
const float STAGGER = 0.45;
// share of a sheet's duration spent unfolding its top onto the wall, before the brush
const float UNFOLD = 0.22;
// length of paper hanging unfolded below the brush, in frame heights; the rest is still folded up behind it
const float FLAP = 0.34;
// how far a sheet overlaps the previous one, in frame widths
const float OVERLAP = 0.006;
// strength of the perspective: how much nearer things grow, per frame height of distance from the wall
const float PERSPECTIVE = 1.2;
// direction towards the light: from the upper left, in front of the wall
const vec3 LIGHT = vec3(-0.25, 0.5, 0.83);
const float RELIEF = 2.5;

float ppHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float ppNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(ppHash(i), ppHash(i + vec2(1.0, 0.0)), f.x),
    mix(ppHash(i + vec2(0.0, 1.0)), ppHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

vec2 ppFold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

// state of sheet k out of n:
// x = height of the brushed edge in the middle of the sheet, y = how much higher that edge is at the sides of the sheet
// (the brush works from the middle outwards), z = angle at which the loose paper leaves the wall, w = its unfolded length
vec4 ppSheet(float k, float n) {
  float dur = END / (1.0 + (n - 1.0) * STAGGER);
  float t = (progress - k * STAGGER * dur) / dur;
  float a = clamp(t / UNFOLD, 0.0, 1.0);
  a = a * a * (3.0 - 2.0 * a);
  float b = max((t - UNFOLD) / (1.0 - UNFOLD), 0.0);
  float f = b < 0.2 ? b * b * 2.5 : b - 0.1;
  float front = 1.0 + 2.0 * AA - f * 1.12 / 0.9;
  float theta = mix(1.35, 0.6, a) - 0.15 * smoothstep(0.0, 0.4, b) + 0.1 * sin(b * 10.0) * (1.0 - smoothstep(0.0, 0.6, b));
  return vec4(front, 0.035 * a, theta, FLAP * a);
}

float ppWrinkle(vec2 q, float k) {
  float a = 1.0 - abs(2.0 * ppNoise(q * vec2(12.0, 2.5) + vec2(k * 13.1, k * 5.7)) - 1.0);
  float b = ppNoise(q * vec2(22.0, 6.0) + vec2(k * 7.3 + 4.0, 2.0));
  return 0.004 * a * a + 0.0015 * b;
}

// relief of the wet paper of sheet k at q (aspect-corrected, on the sheet laid flat): returns its slope.
// Wrinkles flatten with `fresh`; bubbles swell where the brush has just passed, then are pushed flat.
vec2 ppRelief(vec2 q, float k, float fresh, vec4 st, float x0, float x1) {
  float h0 = ppWrinkle(q, k);
  vec2 g = vec2(ppWrinkle(q + vec2(0.002, 0.0), k) - h0, ppWrinkle(q + vec2(0.0, 0.002), k) - h0) * (fresh / 0.002);
  for (int j = 0; j < 3; j++) {
    float fj = float(j);
    vec4 h = vec4(ppHash(vec2(k, fj)), ppHash(vec2(fj, k + 11.0)), ppHash(vec2(k + 5.0, fj + 3.0)), ppHash(vec2(fj + 7.0, k + 2.0)));
    vec2 c = vec2(mix(x0, x1, 0.2 + 0.6 * h.z) * ratio, 0.12 + 0.76 * h.w);
    float e = 0.6 * (2.0 * h.z - 1.0);
    float past = c.y - st.x - st.y * e * e;
    float swell = smoothstep(0.0, 0.08, past) * (1.0 - smoothstep(0.1, 0.55, past));
    float r = (0.03 + 0.03 * h.x) * (0.55 + 0.45 * swell);
    vec2 v = q - c;
    float u = max(1.0 - dot(v, v) / (r * r), 0.0);
    // height 0.12 r (1 - |v|²/r²)²
    g -= v * (0.48 / r) * u * swell * step(0.5, h.y + 0.25 * fj);
  }
  return g;
}

// the loose paper of a sheet, hanging from its brushed edge: it leaves the wall at angle theta, bends down over ARC,
// then hangs straight down to a fold. Returns (coverage with edges of half width w, x and height on the sheet laid flat,
// distance from the wall).
vec4 ppLoose(vec2 p, vec4 st, float x0, float x1, float xl, float xr, float w, float topShift) {
  float th = st.z;
  float c = th / ARC;
  float sinT = sin(th);
  float cosT = cos(th);
  float d1 = sinT / c;
  float x = p.x;
  float h = 0.0;
  float d = 0.0;
  float s = 0.0;
  float z = 0.0;
  float y = p.y;
  // the sheet is seen in perspective, from the middle of the frame: find where it is from where it would be on the wall
  for (int i = 0; i < 3; i++) {
    float e = clamp((x - x0) / (x1 - x0) * 2.0 - 1.0, -1.0, 1.0);
    h = st.x + st.y * e * e;
    d = h - y;
    s = (th - asin(clamp(sinT - c * clamp(d, 0.0, d1), -1.0, 1.0))) / c + max(d - d1, 0.0) + min(d, 0.0);
    z = (cos(th - c * clamp(s, 0.0, ARC)) - cosT) / c;
    x = 0.5 + (p.x - 0.5) * (1.0 - PERSPECTIVE * z);
    y = 0.5 + (p.y - 0.5) * (1.0 - PERSPECTIVE * z);
  }
  y = min(h, 1.0) - s;
  float wx = w / ratio;
  float cov = smoothstep(-AA, AA, d + topShift) * smoothstep(-w, w, y) * smoothstep(-w, w, st.w - s) * smoothstep(-wx, wx, x - xl) * smoothstep(-wx, wx, xr - x);
  return vec4(cov, x, y, z);
}

vec4 transition(vec2 uv) {
  float n = floor(clamp(sheets, 2.0, 8.0) + 0.5);
  float creases = clamp(wrinkles, 0.0, 1.0);
  float wet = 1.0 - smoothstep(END, 1.0, progress);
  float relief = creases * wet;
  float aax = AA / ratio;
  float cover = 0.0; // coverage of the incoming image
  float lit = 0.0; // its shading, premultiplied by the coverage
  float wall = 1.0; // shading of the outgoing image
  vec2 tuv = uv;

  for (int i = 0; i < 8; i++) {
    float k = float(i);
    if (k >= n) break;
    float x0 = k / n;
    float x1 = (k + 1.0) / n;
    float xl = k < 0.5 ? -1.0 : x0 - OVERLAP;
    float xr = k > n - 1.5 ? 2.0 : x1;
    vec4 st = ppSheet(k, n);
    float e = clamp((uv.x - x0) / (x1 - x0) * 2.0 - 1.0, -1.0, 1.0);
    float past = uv.y - st.x - st.y * e * e;
    float inY = smoothstep(-AA, AA, past);
    float cov = inY * smoothstep(-aax, aax, uv.x - xl) * smoothstep(-aax, aax, xr - uv.x);
    float edge = (uv.x - xl) * ratio;
    float seam = 0.3 * wet * step(0.5, k) * inY * (1.0 - smoothstep(0.0, 0.005, -edge)) * step(edge, 0.0);
    lit *= 1.0 - seam;
    wall *= 1.0 - seam;
    if (cov <= 0.0) continue;
    float fresh = 1.0 - smoothstep(0.0, 0.6, past);
    vec2 g = relief > 0.0 ? ppRelief(vec2(uv.x * ratio, uv.y), k, fresh, st, x0, x1) * relief : vec2(0.0);
    float shade = 1.0 - RELIEF * dot(g, LIGHT.xy) / LIGHT.z;
    shade *= (1.0 - 0.08 * fresh * wet) * (1.0 + 0.06 * (1.0 - smoothstep(0.0, 0.2, past)) * wet);
    float overlap = 0.07 * (1.0 - smoothstep(OVERLAP * ratio, OVERLAP * ratio + 0.002, edge));
    float rim = 0.12 * (1.0 - smoothstep(0.0, 0.0025, edge));
    shade *= 1.0 - (overlap - rim) * wet * step(0.5, k);
    tuv = mix(tuv, uv - g * 0.004, cov);
    lit = lit * (1.0 - cov) + shade * cov;
    cover = cover * (1.0 - cov) + cov;
  }

  // loose sheets in front of the wall, each one further out than the previous
  for (int i = 0; i < 8; i++) {
    float k = float(i);
    if (k >= n) break;
    vec4 st = ppSheet(k, n);
    if (st.w <= 0.0 || st.x + st.y < -0.01) continue;
    float x0 = k / n;
    float x1 = (k + 1.0) / n;
    float xl = k < 0.5 ? -1.0 : x0 - OVERLAP;
    float xr = k > n - 1.5 ? 2.0 : x1;
    float topShift = 2.0 * AA;
    float zMax = ARC * (1.0 - cos(st.z)) / st.z * smoothstep(0.0, ARC, st.w);
    vec4 sh = ppLoose(uv + LIGHT.xy / LIGHT.z * zMax * vec2(1.0 / ratio, 1.0), st, x0, x1, xl, xr, AA + 0.5 * zMax, topShift);
    float shadow = 0.5 * sh.x * smoothstep(0.0, 0.04, sh.w);
    lit *= 1.0 - shadow;
    wall *= 1.0 - shadow;
    vec4 l = ppLoose(uv, st, x0, x1, xl, xr, AA, topShift);
    if (l.x <= 0.0) continue;
    float th = acos(clamp(cos(st.z) + l.w * st.z / ARC, -1.0, 1.0));
    vec2 g = relief > 0.0 ? ppRelief(vec2(l.y * ratio, l.z), k, 1.0, st, x0, x1) * relief : vec2(0.0);
    float e = clamp((l.y - x0) / (x1 - x0) * 2.0 - 1.0, -1.0, 1.0);
    float s = min(st.x + st.y * e * e, 1.0) - l.z;
    g.x += 0.8 * creases * smoothstep(0.0, 0.3, s) * cos(l.y * n * 12.57 + k * 2.1 + st.z * 4.0);
    float fold = 1.0 - smoothstep(0.0, 0.035, st.w - s);
    float curl = 1.0 - smoothstep(0.0, 0.04, l.z);
    float shade = (LIGHT.y * sin(th) + LIGHT.z * cos(th)) / LIGHT.z;
    shade *= (1.0 - RELIEF * dot(g, LIGHT.xy) / LIGHT.z) * (1.0 - 0.8 * l.w) * (1.0 - 0.08 * wet) * (1.0 - 0.35 * fold * fold) * (1.0 + 0.15 * curl);
    tuv = mix(tuv, vec2(l.y, l.z) - g * 0.004, l.x);
    lit = lit * (1.0 - l.x) + shade * l.x;
    cover = cover * (1.0 - l.x) + l.x;
  }

  vec4 a = getFromColor(uv);
  vec4 b = getToColor(ppFold(tuv));
  return vec4(a.rgb * wall * (1.0 - cover) + b.rgb * lit, mix(a.a, b.a, cover));
}
