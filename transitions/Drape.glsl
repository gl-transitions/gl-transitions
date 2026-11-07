// Author: gre
// License: MIT
// Description: The outgoing image hangs like a sheet of fabric that is let go at the top: it collapses into soft, uneven folds that hide one another as the cloth bunches up and slides down out of the frame, revealing the incoming image behind it
// Tags: fabric, fold, vertical, 3d, shadow

// @range(1, 16, 1) Number of folds across the cloth (fewer in a portrait image)
uniform float folds; // = 6.0
// @range(0, 1) Depth of the folds and of their shading
uniform float depth; // = 0.7
// @range(0, 1) How much the cloth sways sideways as it falls
uniform float sway; // = 0.4
// @range(0, 1) Strength of the soft shadow cast by the cloth on the incoming image
uniform float shadow; // = 0.5

const float PI = 3.141592653589793;
const int STEPS = 24;
const float DEPTH = 0.8; // height of the deepest folds, times the fold width

// folds a coordinate back into 0..1, mirroring the image at its edges
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// integer-free hash of an integer cell, smoothed into a 1D value noise in 0..1
float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float noise1(float x) {
  float i = floor(x);
  float f = x - i;
  return mix(hash11(i), hash11(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// height of the top edge above x, sagging in the middle (m: see cloth)
float topEdge(float x, vec4 m) {
  float c = 2.0 * x - 1.0;
  return m.y - 0.08 * m.x * (1.0 - c * c);
}

// how far the sides are pulled in at the height sy, more so at the bunched top
float sidePull(float sy, float gT) {
  return 0.035 * gT * (0.3 + 0.7 * clamp(sy, 0.0, 1.0));
}

// height of the cloth at the point (x, y) of the screen plane, toward the viewer,
// or -1 where there is no cloth. Also gives the cloth's own coordinates and fold phase.
// m: how far the folds have formed (0 at rest), height of the top edge, height of the hem, sideways swing
vec4 cloth(vec2 p, vec4 m, float foldN) {
  float gT = m.x;
  float botY = m.z;
  float x = p.x - m.w;
  float top = topEdge(x, m);
  float sy = (p.y - botY) / max(top - botY, 1e-4); // 0 at the hem, 1 at the top edge
  float pull = sidePull(sy, gT);
  float xc = (x - pull) / (1.0 - 2.0 * pull);
  // uneven folds: their width, depth and course along the cloth all wander
  float wander = (noise1(0.5 * foldN * xc + 2.5 * sy + 5.3) - 0.5) * 2.4 * (1.0 - sy);
  float ph = 2.0 * PI * (foldN * xc + 0.6 * noise1(0.7 * foldN * xc + 1.7)) + wander;
  float d = 0.15 + 0.85 * noise1(1.1 * foldN * xc + 1.4 * sy + 7.0);
  // deepest near the bunched top, relaxing toward the hem
  float amp = DEPTH * depth * gT * (0.3 + 0.7 * sy * sqrt(max(sy, 0.0))) / max(foldN, 2.0);
  // the free sides of the cloth hang flat
  float w = 0.6 / foldN;
  amp *= smoothstep(0.0, w, xc) * smoothstep(0.0, w, 1.0 - xc);
  float prof = 0.5 - 0.5 * cos(ph); // 1 on a ridge, 0 in a valley
  // small sagging creases where the fabric piles up under the top edge
  float dt = (1.0 - sy) * (top - botY);
  float crease = exp(-30.0 * dt) * (0.5 + 0.5 * sin(80.0 * dt + 0.7 * ph));
  bool on = sy >= 0.0 && sy <= 1.0 && xc >= 0.0 && xc <= 1.0;
  return on ? vec4(amp * (d * prof + 0.15 * crease), xc, sy, ph) : vec4(-1.0);
}

vec4 transition (vec2 uv) {
  float t = progress;
  // the top edge falls first and the hem follows later: the cloth collapses as it slides down
  float topY = 1.0 - 1.06 * t * (0.35 + 0.65 * t);
  float botY = -0.75 * t * t * t;
  // the folds form as soon as the top is let go
  float f = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
  float foldN = max(1.0, floor(folds * min(ratio, 1.0) + 0.5));
  float shiftX = sway * 0.035 * sin(2.0 * PI * t) * f;
  // the cloth is seen a little from the left and from above: ridges hide the valleys behind them
  vec2 view = vec2(0.75 + 0.5 * sway * sin(PI * t) * f, -0.35);
  float zMax = 1.15 * DEPTH * depth * f / max(foldN, 2.0); // a single fold is no deeper than two
  vec4 m = vec4(f, topY, botY, shiftX);
  // march from the front toward the screen plane, the first point inside the cloth is visible
  float zA = zMax; // last step in front of the cloth
  float zB = 0.0; // first step inside it
  bool found = false;
  float dA = 0.0;
  float dB = 0.0;
  bool onA = false; // whether the last step in front was over the cloth (else the ray came in through its edge)
  for (int i = 0; i < STEPS; i++) {
    if (!found) {
      float z = max(zMax * (1.0 - float(i) / float(STEPS - 1)), 0.0);
      vec4 s = cloth(uv - view * z, m, foldN);
      float dz = s.x - z;
      if (s.x >= 0.0 && dz >= 0.0) {
        found = true;
        zB = z;
        dB = dz;
      } else {
        zA = z;
        dA = dz;
        onA = s.x >= 0.0;
      }
    }
  }
  float zHit = zB;
  if (found && zA > zB) {
    if (onA) {
      // crossed the surface: refine between the last two steps
      zHit = mix(zA, zB, dA / (dA - dB));
    } else {
      // came in through the top edge: find where the ray first meets the cloth,
      // on its surface or through the edge (then it sees the inside of the fold)
      float za = zA;
      for (int j = 0; j < 5; j++) {
        float zm = 0.5 * (za + zHit);
        if (cloth(uv - view * zm, m, foldN).x >= zm) zHit = zm;
        else za = zm;
      }
    }
  }
  vec2 hp = uv - view * zHit;
  vec4 hit = found ? cloth(hp, m, foldN) : vec4(-1.0);
  if (found && hit.x < 0.0) {
    zHit = zB;
    hp = uv - view * zB;
    hit = cloth(hp, m, foldN);
  }
  vec4 col = vec4(0.0);
  float cover = 0.0;
  if (hit.x >= 0.0) {
    float xc = hit.y;
    float sy = hit.z;
    float ph = hit.w;
    // the fabric is gathered: more of it goes into the slopes of the folds
    float slope = PI * zMax * foldN;
    // (capped so that the texture never runs backwards where the folds bunch up)
    float mu = min(0.25 * slope * slope / (1.0 + 0.25 * slope * slope), 0.5);
    float u = xc - mu * sin(2.0 * ph) / (4.0 * PI * foldN);
    // and pushed together under the top edge
    float h = max(topY - botY, 1e-4);
    float comp = max(1.0 - h, 0.0);
    float v = sy * (1.0 - comp) + comp * sy * sy * sy;
    vec4 tex = getFromColor(mirror(vec2(u, v)));
    float span = topEdge(hp.x - shiftX, m) - botY; // local height of the cloth
    // surface normal from the height of the cloth around the visible point
    float e = 0.002;
    float hx = cloth(hp + vec2(e, 0.0), m, foldN).x;
    float hy = cloth(hp + vec2(0.0, e), m, foldN).x;
    float hx0 = hx >= 0.0 ? hx : hit.x;
    float hy0 = hy >= 0.0 ? hy : hit.x;
    vec3 nrm = normalize(vec3(-(hx0 - hit.x) / e, -(hy0 - hit.x) / e, 1.0));
    vec3 light = normalize(vec3(-0.45, 0.35, 1.0));
    float diffuse = mix(1.0, max(dot(nrm, light), 0.0) / light.z, min(1.0, 3.0 * f));
    // soft ambient occlusion in the valleys, deeper where the folds are deep
    float valley = 1.0 - (0.5 - 0.5 * cos(ph));
    float ao = 1.0 - 0.6 * depth * f * valley * valley * (0.35 + 0.65 * sy);
    // the rolled top edge gets less light
    float rim = exp(-(1.0 - sy) * span * 70.0) * 0.35 * f;
    // below the surface, the ray sees the shaded inside of a fold through the top edge
    float under = max(hit.x - zHit, 0.0);
    float back = min(1.0, under / max(0.1 * zMax, 1e-6));
    tex.rgb *= diffuse * ao * (1.0 - rim) * (1.0 - 0.6 * back);
    col = tex;
    // anti-aliased outline, sharp at rest so the first frame is exact
    float aa = 0.003 * f;
    float inside = min((1.0 - sy) * span - view.y * under, min(xc, 1.0 - xc));
    cover = aa > 0.0 ? clamp(inside / aa, 0.0, 1.0) : 1.0;
    if (cover >= 1.0) return col;
  }
  // soft shadow of the cloth, held a little away from the incoming image, gone once it has left
  vec4 to = getToColor(uv);
  float x = uv.x - shiftX;
  float pull = sidePull((uv.y - botY) / max(topEdge(x, m) - botY, 1e-4), f);
  float outside = max(uv.y - topEdge(x, m), max(-x, x - 1.0) - pull);
  float sh = shadow * exp(-max(outside, 0.0) * 16.0) * f * clamp(8.0 * (1.0 - t), 0.0, 1.0);
  return mix(vec4(to.rgb * (1.0 - 0.8 * sh), to.a), col, cover);
}
