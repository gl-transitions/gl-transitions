// Author: gre
// License: MIT
// Description: The outgoing picture is a tray of stuck tiles that is wrenched: its two ends twist against each other in 3D while cracks run out along the joints, it snaps back flat, and the loosened tiles tip out one after another and fall out of the frame, uncovering the incoming picture
// Tags: 3d, tiles, twist, crack, gravity, shadow

// @range(2, 8, 1) Number of rows of tiles
uniform int rows; // = 4
// @range(0, 1) How far the two ends of the tray turn against each other
uniform float twist; // = 0.75
// @range(0, 1) How much the tiles darken as they turn from the light, and the shadows they cast
uniform float shading; // = 0.6

const float PI = 3.14159265;
const float EYE = 1.8;
const float TWIST_END = 0.48;
const float POP_SPREAD = 0.24;
const float FLIGHT = 0.28;
const float THICK = 0.03;
const float EDGE = 0.0015;
const vec3 L = vec3(-0.3, 0.45, 0.84);

vec4 hash4(vec2 p) {
  vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  q += dot(q, q.wzxy + 33.33);
  return fract((q.xxyz + q.yzzw) * q.zywx);
}

// wind up, then a released snap that rings out to exactly zero
float wrench(float s) {
  if (s < 0.75) return smoothstep(0.0, 0.75, s);
  float r = (s - 0.75) / 0.25;
  return (1.0 - r) * (1.0 - r) * cos(2.5 * PI * r);
}

// when the crack front reaches a point of the joints: it runs along them from the middle node
float arrival(vec2 f, vec2 seg, vec2 grid, vec2 size) {
  vec2 o = clamp(floor(0.5 * grid + 0.5), vec2(1.0), max(grid - 1.0, vec2(1.0)));
  vec2 far = max(o, grid - o) * size;
  float d = dot(abs(f - o), size) / (far.x + far.y);
  return 0.75 * d + 0.25 * hash4(seg + 41.0).x;
}

float popU(vec2 g, vec2 grid, vec2 size) {
  float order = clamp((0.55 * hash4(g).x + 0.45 * arrival(g + 0.5, vec2(-7.0), grid, size) - 0.2) / 0.62, 0.0, 1.0);
  return clamp((progress - TWIST_END - POP_SPREAD * order) / FLIGHT, 0.0, 1.0);
}

float lambert(vec3 n, float shade) {
  return 1.0 + shade * 0.8 * (max(dot(n, L), 0.0) / L.z - 1.0);
}

// a rectangle of half size h on the plane (c, ex, ey) hit by the ray o + t d: (coverage, t, local x, local y);
// grow widens it by one edge on the sides it shares with another visible face, so no seam shows between them
vec4 face(vec3 o, vec3 d, vec3 c, vec3 ex, vec3 ey, vec2 h, vec2 grow) {
  vec3 n = cross(ex, ey);
  float dn = dot(n, d);
  if (abs(dn) < 1e-5) return vec4(0.0);
  float t = dot(n, c - o) / dn;
  vec3 x = o + t * d - c;
  vec2 l = vec2(dot(x, ex), dot(x, ey));
  float e = EDGE * max(t, 0.1) / max(abs(dn) / length(d), 0.25);
  vec2 m = h + 0.5 * e * abs(grow) - abs(l - 0.5 * e * grow);
  return vec4(clamp(min(m.x, m.y) / e + 0.5, 0.0, 1.0) * step(0.1, t), t, l);
}

// the crack along one family of joints: (darkness, lit lip)
vec2 crackAt(float fa, float fb, float n, float other, vec2 grid, vec2 size, float sz, float cp, float widen, float lipSide) {
  float j = floor(fa + 0.5);
  if (j < 1.0 || j > n - 1.0) return vec2(0.0);
  vec2 f = other > 0.0 ? vec2(fb, j) : vec2(j, fb);
  vec2 seg = other > 0.0 ? vec2(floor(fb), j + 20.0) : vec2(j, floor(fb));
  float open = clamp((cp - arrival(f, seg, grid, size)) / 0.1, 0.0, 1.0);
  float w = (0.004 + 0.006 * widen) * open;
  float sd = (fa - j) * sz;
  float e = 0.0012;
  float k = clamp((0.5 * w - abs(sd)) / e + 0.5, 0.0, 1.0) * clamp(w / e, 0.0, 1.0);
  float lip = clamp(1.0 - abs(sd * lipSide - 0.5 * w - 0.002) / 0.002, 0.0, 1.0) * open;
  return vec2(k, lip);
}

vec4 transition(vec2 uv) {
  vec2 aspect = vec2(ratio, 1.0);
  vec2 P = (uv - 0.5) * aspect;
  float n = clamp(float(rows), 1.0, 8.0);
  vec2 grid = vec2(max(1.0, floor(ratio * n + 0.5)), n);
  vec2 size = aspect / grid;
  float shade = clamp(shading, 0.0, 1.0);
  float s = clamp(progress / TWIST_END, 0.0, 1.0);
  float amp = 1.25 * clamp(twist, 0.0, 1.0) * wrench(s);
  float k2 = 2.0 * amp / ratio;

  // invert the perspective of the twisted tray: each column x turns by th(x) about the horizontal axis
  vec2 q = P;
  float c = 1.0, sn = 0.0;
  for (int k = 0; k < 10; k++) {
    float th = amp * clamp(2.0 * q.x / ratio, -1.0, 1.0);
    c = cos(th);
    sn = sin(th);
    q.y = P.y * EYE / (c * EYE + P.y * sn);
    q.x = P.x * (EYE - q.y * sn) / EYE;
  }

  vec4 col = getToColor(uv);
  col.rgb *= 1.0 - 0.45 * shade * (1.0 - smoothstep(0.5, 1.0, progress));

  vec2 f = (q + 0.5 * aspect) / size;
  vec2 cell = floor(f);
  // the edges only soften once the tray turns, so it covers the frame exactly at rest
  float soft = 1.0 - min(20.0 * amp, 1.0);
  float inX = clamp((0.5 * ratio - abs(q.x)) / EDGE + soft, 0.0, 1.0);

  // the tray's top or bottom edge, seen as it turns
  float Y = q.y > 0.0 ? 0.5 : -0.5;
  float den = P.y * c - EYE * sn;
  float dd = abs(den) > 1e-5 ? (EYE * Y * c - P.y * (EYE - Y * sn)) / den : -1.0;
  float band = inX * clamp(dd / EDGE + 0.5, 0.0, 1.0) * clamp((THICK - dd) / EDGE + 0.5, 0.0, 1.0) * step(0.5, abs(q.y)) * step(abs(q.y), 0.6);
  if (band > 0.0) {
    vec4 e = getFromColor(vec2(q.x / ratio + 0.5, Y > 0.0 ? 0.995 : 0.005));
    e.rgb *= lambert(vec3(0.0, Y * 2.0 * c, Y * 2.0 * sn), shade) * (1.0 - 0.25 * shade);
    col = mix(col, e, band);
  }

  float inside = inX * clamp((0.5 - abs(q.y)) / EDGE + soft, 0.0, 1.0);
  float pu = popU(cell, grid, size);
  float cp = (s - 0.1) / 0.62;
  float widen = smoothstep(0.75, 0.85, s);
  vec2 cv = crackAt(f.x, f.y, grid.x, 0.0, grid, size, size.x, cp, widen, 1.0);
  vec2 ch = crackAt(f.y, f.x, grid.y, 1.0, grid, size, size.y, cp, widen, -1.0);
  float crack = max(cv.x, ch.x);
  if (inside > 0.0 && pu <= 0.0) {
    float lip = max(cv.y, ch.y) * (1.0 - crack);
    // once a tile is cracked loose it turns as one flat piece
    vec2 cc = (cell + 0.5) * size - 0.5 * aspect;
    float loose = clamp((cp - arrival(cell + 0.5, vec2(-3.0), grid, size)) / 0.3, 0.0, 1.0);
    float thc = amp * clamp(2.0 * cc.x / ratio, -1.0, 1.0);
    vec3 nSmooth = normalize(vec3(-q.y * k2, -sn, c));
    vec3 nFlat = vec3(0.0, -sin(thc), cos(thc));
    float lit = lambert(normalize(mix(nSmooth, nFlat, loose)), shade);
    // cracked tiles slip against each other while the tray is wrenched
    vec2 slip = (hash4(cell + 5.0).xy - 0.5) * 0.012 * loose * wrench(s);
    vec4 tile = getFromColor((q - slip) / aspect + 0.5);
    tile.rgb = tile.rgb * lit * (1.0 - 0.8 * crack) + 0.3 * lip * tile.a;
    col = mix(col, tile, inside);
  } else if (pu > 0.0) {
    // contact shadow inside the hole, along the sides whose neighbour is still in place
    vec2 fl = fract(f) * size;
    float ao = 0.0;
    if (popU(cell + vec2(-1.0, 0.0), grid, size) <= 0.0 && cell.x > 0.0) ao = max(ao, 1.0 - fl.x / 0.03);
    if (popU(cell + vec2(1.0, 0.0), grid, size) <= 0.0 && cell.x < grid.x - 1.0) ao = max(ao, 1.0 - (size.x - fl.x) / 0.03);
    if (popU(cell + vec2(0.0, -1.0), grid, size) <= 0.0 && cell.y > 0.0) ao = max(ao, 1.0 - fl.y / 0.03);
    if (popU(cell + vec2(0.0, 1.0), grid, size) <= 0.0 && cell.y < grid.y - 1.0) ao = max(ao, 1.0 - (size.y - fl.y) / 0.03);
    col.rgb *= (1.0 - 0.5 * shade * clamp(ao, 0.0, 1.0)) * (1.0 - 0.8 * crack * (1.0 - smoothstep(0.0, 0.25, pu)));
  }

  // loosened tiles: each tips forward over its bottom edge, then falls
  vec3 eye = vec3(0.0, 0.0, EYE);
  vec3 dir = vec3(P, -EYE);
  float shadow = 0.0;
  float bestT = 1e5, nextT = 1e5;
  float topM = 0.0, nextM = 0.0;
  vec2 topUv = vec2(0.5), nextUv = vec2(0.5);
  float topLit = 1.0, nextLit = 1.0;
  // perspective pushes the tiles outward, so look around where this pixel was before
  float pcx = floor((P.x / 1.1 + 0.5 * ratio) / size.x);
  vec3 hs = vec3(0.5 * size, 0.5 * THICK);
  for (int j = 0; j < 8; j++) {
    if (float(j) >= grid.y) break;
    for (int i = -3; i <= 3; i++) {
      vec2 g = vec2(pcx + float(i), float(j));
      if (g.x < 0.0 || g.x >= grid.x) continue;
      float u = popU(g, grid, size);
      if (u <= 0.0 || u >= 1.0) continue;
      vec4 h = hash4(g + 17.0);
      vec2 c0 = (g + 0.5) * size - 0.5 * aspect;
      float fall = max(u - 0.2, 0.0);
      float a = (0.9 + 0.3 * h.y) * u * (1.6 - 0.6 * u);
      float r = (h.z - 0.5) * 0.6 * fall;
      float ca = cos(a), sa = sin(a), cr = cos(r), sr = sin(r);
      vec3 ex = vec3(cr, sr, 0.0);
      vec3 ey = vec3(-sr * ca, cr * ca, sa);
      vec3 ez = vec3(sr * sa, -cr * sa, ca);
      vec3 pivot = vec3(c0.x + (h.w - 0.5) * 0.2 * fall, c0.y - hs.y - (c0.y - hs.y + 0.55 + 0.9 * size.y) * fall * fall / 0.64, 0.07 * smoothstep(0.0, 0.12, u) + 0.25 * fall);
      // the tile keeps the crack gap that opened along its inner joints
      vec2 lo = 0.005 * step(0.5, g);
      vec2 hi = 0.005 * step(g, grid - 1.5);
      vec2 hf = hs.xy - 0.5 * (lo + hi);
      vec2 off = 0.5 * (lo - hi);
      vec3 ctr = pivot + ey * hs.y - ez * hs.z + ex * off.x + ey * off.y;
      vec3 toEye = eye - ctr;
      float sy = dot(ey, toEye) > 0.0 ? 1.0 : -1.0;
      float sx = dot(ex, toEye) > 0.0 ? 1.0 : -1.0;
      float sz = dot(ez, toEye) > 0.0 ? 1.0 : -1.0;

      vec4 F = face(eye, dir, ctr + ez * (sz * hs.z), ex, ey, hf, vec2(sx, sy));
      vec4 Sy = face(eye, dir, ctr + ey * (sy * hf.y), ex, ez, vec2(hf.x, hs.z), vec2(sx, sz));
      vec4 Sx = face(eye, dir, ctr + ex * (sx * hf.x), ey, ez, vec2(hf.y, hs.z), vec2(sy, sz));
      float m = max(F.x, max(Sy.x, Sx.x));

      vec2 ax = ex.xy - L.xy / L.z * ex.z;
      vec2 ay = ey.xy - L.xy / L.z * ey.z;
      vec2 sd = P - (ctr.xy - L.xy / L.z * ctr.z);
      float det = ax.x * ay.y - ax.y * ay.x;
      // nearly edge-on to the light the shadow is a sliver: fade it rather than stretch it
      float edgeOn = smoothstep(0.02, 0.15, abs(det));
      det = abs(det) < 0.05 ? (det < 0.0 ? -0.05 : 0.05) : det;
      vec2 sl = vec2(sd.x * ay.y - sd.y * ay.x, ax.x * sd.y - ax.y * sd.x) / det;
      float blur = 0.004 + 0.12 * ctr.z;
      vec2 sb = hs.xy - abs(sl);
      shadow = max(shadow, smoothstep(-blur, blur, min(sb.x, sb.y)) * (1.0 - u) * smoothstep(0.0, 0.05, u) * edgeOn / (1.0 + 2.0 * ctr.z));

      if (m <= 0.0) continue;
      float t = 1e5;
      vec2 st = vec2(0.0);
      float lit = 1.0;
      if (F.x > 0.0) {
        t = F.y;
        st = c0 + off + F.zw;
        // the unglazed back shows darker
        lit = lambert(ez * sz, shade) * (sz > 0.0 ? 1.0 : 0.6);
      }
      if (Sy.x > 0.0 && Sy.y < t - 1e-4 && F.x < 0.99) {
        t = Sy.y;
        st = c0 + off + vec2(Sy.z, sy * (hf.y - 0.002));
        lit = lambert(ey * sy, shade) * (1.0 - 0.2 * shade);
      }
      if (Sx.x > 0.0 && Sx.y < t - 1e-4 && F.x < 0.99) {
        t = Sx.y;
        st = c0 + off + vec2(sx * (hf.x - 0.002), Sx.z);
        lit = lambert(ex * sx, shade) * (1.0 - 0.2 * shade);
      }
      if (t < bestT) {
        nextT = bestT;
        nextM = topM;
        nextUv = topUv;
        nextLit = topLit;
        bestT = t;
        topM = m;
        topUv = st / aspect + 0.5;
        topLit = lit;
      } else if (t < nextT) {
        nextT = t;
        nextM = m;
        nextUv = st / aspect + 0.5;
        nextLit = lit;
      }
    }
  }
  col.rgb *= 1.0 - 0.6 * shade * shadow;
  vec4 behind = getFromColor(clamp(nextUv, 0.0, 1.0));
  behind.rgb *= nextLit;
  vec4 top = getFromColor(clamp(topUv, 0.0, 1.0));
  top.rgb *= topLit;
  return mix(mix(col, behind, nextM), top, topM);
}
