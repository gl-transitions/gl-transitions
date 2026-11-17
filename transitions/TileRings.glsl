// Author: gre
// License: MIT
// Description: The image is cut into tiles that ride concentric rectangular rings like the dials of a combination lock: the rings turn a quarter of the way round in alternating directions, the tiles turning the corners like links of a chain, then the tiles flip over to the incoming image in a ripple running round each ring, and the rings turn back until every tile clicks home
// Tags: tiles, rings, rotate, flip, puzzle, mechanical

// @range(2, 4, 1) Number of rings, from the border to the center
uniform int rings; // = 3
// @range(0, 0.4) Delay between the innermost ring and the outermost one, as a part of the transition
uniform float stagger; // = 0.15
// @range(0, 1) Darkness of the shadows cast by the lifted tiles
uniform float shadow; // = 0.5
// @color Color of the tray seen between the tiles
uniform vec4 backColor; // = vec4(0.1, 0.1, 0.11, 1.0)

const float PI = 3.141592653589793;
const float GAP = 0.035;
const float EYE = 3.0;
const vec2 LIGHT = vec2(0.12, -0.16);

float ringOf(vec2 c, vec2 dims) {
  return min(min(c.x, c.y), min(dims.x - 1.0 - c.x, dims.y - 1.0 - c.y));
}

// counted counterclockwise from the ring's bottom left corner
float indexOf(vec2 c, float r, vec2 wh) {
  vec2 q = c - r;
  if (q.y < 0.5) return q.x;
  if (q.x > wh.x - 0.5) return wh.x + q.y;
  if (q.y > wh.y - 0.5) return 2.0 * wh.x + wh.y - q.x;
  return 2.0 * (wh.x + wh.y) - q.y;
}

vec2 cellAt(float k, float r, vec2 wh) {
  float L = 2.0 * (wh.x + wh.y);
  k = mod(k, L);
  vec2 q = k < wh.x ? vec2(k, 0.0)
    : k < wh.x + wh.y ? vec2(wh.x, k - wh.x)
    : k < 2.0 * wh.x + wh.y ? vec2(2.0 * wh.x + wh.y - k, wh.y)
    : vec2(0.0, L - k);
  return q + r;
}

float smooth3(float u) {
  return u * u * (3.0 - 2.0 * u);
}

// overshoots by about 1.5% near the end so the ring settles like a detent
float ease(float u) {
  float s = sin(PI * u);
  return smooth3(u) + 0.6 * u * u * u * s * s;
}

float edge(float d, float px) {
  return clamp(0.5 - d / px, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  float R = clamp(float(rings), 2.0, 4.0);
  float sh = 2.0 * R;
  float lg = max(sh, floor(sh * max(ratio, 1.0 / ratio) + 0.5));
  vec2 dims = ratio >= 1.0 ? vec2(lg, sh) : vec2(sh, lg);
  vec2 P = uv * dims;
  vec2 here = clamp(floor(P), vec2(0.0), dims - 1.0);
  float px = sh / 600.0;
  float open = sin(PI * progress);
  // resting tiles overlap by a few pixels to hide their seams
  float hs = 0.5 - GAP * open + 2.0 * px * (1.0 - smoothstep(0.0, 0.1, open));
  float st = clamp(stagger, 0.0, 0.4);

  float z1 = -9.0, z2 = -9.0, cov1 = 0.0, cov2 = 0.0, a1 = 0.0, a2 = 0.0;
  vec2 s1 = P, s2 = P;
  float shade = 0.0;
  for (int pass = 0; pass < 2; pass++) {
    for (int j = 0; j < 9; j++) {
      vec2 c = here + vec2(mod(float(j), 3.0), floor(float(j) / 3.0)) - 1.0;
      if (c.x >= 0.0 && c.y >= 0.0 && c.x < dims.x && c.y < dims.y) {
        float r = ringOf(c, dims);
        vec2 wh = dims - 1.0 - 2.0 * r;
        float L = 2.0 * (wh.x + wh.y);
        float t = clamp((progress - st * (R - 1.0 - r) / (R - 1.0)) / (1.0 - st), 0.0, 1.0);
        float u1 = clamp(t / 0.34, 0.0, 1.0), u2 = clamp((t - 0.66) / 0.34, 0.0, 1.0);
        float s = floor(0.25 * L + 0.5) * (mod(r, 2.0) < 0.5 ? 1.0 : -1.0) * (ease(u1) - ease(u2));
        float k = indexOf(c, r, wh);
        float fs = s - floor(s);
        float h = mod(k - floor(s), L);
        vec2 home = cellAt(h, r, wh) + 0.5;
        vec2 ctr = mix(c, cellAt(k + 1.0, r, wh), fs) + 0.5;
        float a = PI * smooth3(smooth3(clamp((t - 0.34 - 0.2 * h / L) / 0.12, 0.0, 1.0)));
        float sa = max(sin(a), 0.0), ca = cos(a);
        float ride = 0.5 * (sin(PI * u1) + sin(PI * u2));
        float lift = 0.5 * ride + sa;
        float sc = 1.0 + 0.04 * ride + 0.15 * sa;
        if (pass == 0) {
          // perspective flip about the tile's vertical axis
          vec2 d = (P - ctr) / sc;
          float den = EYE * ca + d.x * sa;
          den = abs(den) < 1e-5 ? 1e-5 : den;
          float x = d.x * EYE / den;
          vec2 lp = vec2(x, d.y * (EYE - x * sa) / EYE);
          vec2 ink = sc * vec2(max(abs(ca), 0.05), 1.0);
          vec2 e = (abs(lp) - hs) * ink;
          float cv = den * ca > 0.0 || abs(ca) < 0.05 ? edge(e.x, px) * edge(e.y, px) : 0.0;
          float z = lift + 0.001 * cv;
          vec2 src = home + vec2(ca < 0.0 ? -lp.x : lp.x, lp.y);
          // the incoming face lies flat in the slot under a flipping tile, so no tray shows
          vec2 f = abs(P - ctr) - hs;
          float under = sa > 0.0 ? edge(f.x, px) * edge(f.y, px) : 0.0;
          for (int m = 0; m < 2; m++) {
            float cm = m == 0 ? cv : under;
            float zm = m == 0 ? z : -1.0;
            float am = m == 0 ? a : PI;
            vec2 sm = m == 0 ? src : home + P - ctr;
            if (cm > 0.0 && zm > z1) {
              z2 = z1; cov2 = cov1; a2 = a1; s2 = s1;
              z1 = zm; cov1 = cm; a1 = am; s1 = sm;
            } else if (cm > 0.0 && zm > z2) {
              z2 = zm; cov2 = cm; a2 = am; s2 = sm;
            }
          }
        } else if (lift > z1 + 0.01) {
          vec2 d = (P - ctr - LIGHT * lift) / sc;
          vec2 b = abs(d * vec2(1.0 / max(abs(ca), 0.05), 1.0)) - hs;
          float w = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0);
          float blur = 0.04 + 0.12 * lift;
          shade = max(shade, min(lift - max(z1, 0.0), 1.0) * (1.0 - smoothstep(-blur, blur, w)));
        }
      }
    }
  }

  vec4 col = backColor;
  if (cov2 > 0.0) {
    vec2 q = clamp(s2 / dims, 0.0, 1.0);
    vec4 c2 = cos(a2) < 0.0 ? getToColor(q) : getFromColor(q);
    float sa = sin(a2);
    c2.rgb *= 1.0 - 0.45 * sa * sa + 0.2 * sa * abs(cos(a2));
    col = mix(col, c2, cov2);
  }
  vec2 q = clamp(s1 / dims, 0.0, 1.0);
  vec4 c1 = cos(a1) < 0.0 ? getToColor(q) : getFromColor(q);
  float sa = sin(a1);
  c1.rgb *= 1.0 - 0.45 * sa * sa + 0.2 * sa * abs(cos(a1));
  col = mix(col, c1, cov1);
  col.rgb *= 1.0 - 0.6 * shadow * shade;
  return col;
}
