// Author: gre
// License: MIT
// Description: The outgoing image collapses along a herringbone of zigzag creases like a folded map: in one motion it pleats in both directions at once, its facets lit and shaded in alternation, into a small compact packet that drops out of the frame, revealing the incoming image under its shadow
// Tags: fold, origami, paper, 3d, mechanical, shadow

// @range(2, 8) Number of pleat rows across the height of the frame
uniform float rows; // = 4.0
// @range(0, 1) Darkness of the shadow cast by the folding sheet
uniform float shadow; // = 0.6

const float GAMMA = 1.2;
const float WIDTH = 0.65;
const vec3 LIGHT = vec3(-0.4, 0.3, 0.866); // unit length

float tri(float x) {
  return 1.0 - abs(mod(x, 2.0) - 1.0);
}

// slope sign of tri(), softened over e around the creases
float slope(float x, float e) {
  float m = mod(x, 2.0);
  float d = min(min(m, abs(m - 1.0)), 2.0 - m);
  return (m < 1.0 ? 1.0 : -1.0) * smoothstep(0.0, e, d);
}

// a translational surface of two zigzags folds rigidly: every facet keeps its shape.
// x: column width, y: pleat height, z: zigzag offset, w: row height, all seen from above
vec4 pleats(float t, float b, float a) {
  float V = a * cos(GAMMA) / cos(t);
  return vec4(b * cos(t), b * sin(t), V, sqrt(max(a * a - V * V, 1e-6)));
}

// sheet uv, signed distance to the sheet edge, column coordinate
vec4 unfold(vec2 P, vec4 g, vec2 frame, float b, float c, float n) {
  float y = P.y / g.w;
  // the side edges zigzag by g.z - c * cos(t) on screen: centered, and their distance measured across
  float z = g.z - c * g.x / b;
  float w = (P.x + 0.5 * z - g.z * tri(y)) / g.x;
  vec2 fp = vec2(w * b + c * tri(y), y / n) + 0.5 * frame;
  vec2 e = min(fp, frame - fp) * vec2(g.x / b / sqrt(1.0 + z * z / (g.w * g.w)), g.w * n);
  return vec4(fp / frame, min(e.x, e.y), w);
}

vec4 transition(vec2 uv) {
  float n = max(rows, 1.0);
  float b = WIDTH / n;
  float a = 1.0 / (n * sin(GAMMA));
  float c = a * cos(GAMMA);
  vec2 frame = vec2(ratio, 1.0);
  float f = smoothstep(0.0, 0.7, progress);
  float d = smoothstep(0.5, 1.0, progress);
  float t = f * GAMMA * 0.985;
  vec4 g = pleats(t, b, a);
  // the packet recedes as it falls
  vec2 P = (uv * frame - 0.5 * frame + vec2(0.0, 0.75 * d * d * d)) * (1.0 + 0.6 * d);

  vec4 m = unfold(P, g, frame, b, c, n);
  float aa = 0.0025 * (1.0 + 0.6 * d);
  // the edge bias keeps the border pixels fully covered at the start
  float cov = clamp(0.5 + (m.z + 0.004 * (1.0 - f)) / aa, 0.0, 1.0);

  float s1 = slope(m.w, 0.003 / g.x);
  float s2 = slope(P.y / g.w, 0.003 / g.w);
  float k = g.y / g.x;
  vec3 nrm = normalize(vec3(-k * s1, k * s1 * g.z * s2 / g.w, 1.0));
  float lit = clamp(dot(nrm, LIGHT) / LIGHT.z, 0.0, 1.06);
  float spec = pow(max(reflect(-LIGHT, nrm).z, 0.0), 40.0) - pow(LIGHT.z, 40.0);
  float valley = 1.0 - smoothstep(0.0, 0.004 / g.x, abs(mod(m.w + 1.0, 2.0) - 1.0));
  vec4 sheet = getFromColor(clamp(m.xy, 0.0, 1.0));
  sheet.rgb = min(sheet.rgb * (0.3 + 0.7 * lit) * (1.0 - 0.3 * sin(t) * valley) + 0.08 * max(spec, 0.0), 1.0);

  // paper thickness: the sheet's silhouette nudged down, drawn as a darker rim
  vec4 r = unfold(P + vec2(0.0, 0.005 * f), g, frame, b, c, n);
  float rim = clamp(0.5 + r.z / aa, 0.0, 1.0);
  vec4 edge = getFromColor(clamp(r.xy, 0.0, 1.0));
  edge.rgb *= 0.45;

  vec4 next = getToColor(uv);
  float soft = 0.02 + 0.06 * d;
  float sd = unfold(P - vec2(0.02, -0.04) * (0.3 + f + 2.0 * d), g, frame, b, c, n).z;
  next.rgb *= 1.0 - shadow * (1.0 - 0.5 * d) * smoothstep(-soft, soft, sd) * smoothstep(0.0, 0.15, f);

  return mix(mix(next, edge, rim), sheet, cov);
}
