// Author: gre
// License: MIT
// Description: The outgoing image is a layer of sand on a vibrating plate: it shivers, then runs together into the symmetric lines of a sound figure, uncovering the incoming image beneath as the plate, before the lines thin out and their grains hop off
// Tags: sand, particles, pattern, symmetry, reveal

// @range(1, 6) Vibration mode across the plate: more nodal lines with a larger value
uniform float modeX; // = 3.0
// @range(1, 8) Vibration mode along the plate: more nodal lines with a larger value
uniform float modeY; // = 5.0
// @range(0.1, 0.8) Width of the lines of sand once gathered
uniform float lineWidth; // = 0.45

const float PI = 3.14159265;
const float GRAINS = 140.0;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float t = progress;
  // a square plate on the short side keeps the figure symmetric at any aspect ratio
  float side = min(ratio, 1.0);
  vec2 toPlate = vec2(ratio, 1.0) / side;
  vec2 p = (uv - 0.5) * toPlate + 0.5;

  float n = modeX * PI;
  float m = modeY * PI;
  // equal modes would cancel out to f = 0 everywhere: close modes switch to the sum, a plain grid of lines
  float c = 1.0 - 2.0 * smoothstep(0.0, 1.0, abs(modeX - modeY));
  vec2 cn = cos(n * p);
  vec2 cm = cos(m * p);
  vec2 sn = sin(n * p);
  vec2 sm = sin(m * p);
  float f = cn.x * cm.y + c * cm.x * cn.y;
  vec2 g = -vec2(n * sn.x * cm.y + c * m * sm.x * cn.y, m * cn.x * sm.y + c * n * cm.x * sn.y);
  float gl2 = max(dot(g, g), 1e-3);

  // sand covers |f| < w; |f| <= 2, so w = 3.2 covers the whole plate with the grainy edge
  float x = clamp(t / 0.55, 0.0, 1.0);
  float gather = x * (1.6 - 0.6 * x);
  float w = mix(3.2, lineWidth, gather) * (1.0 - smoothstep(0.5, 0.97, t));
  float shake = smoothstep(0.0, 0.08, t) * (1.0 - 0.6 * smoothstep(0.4, 0.75, t));

  vec2 gid = floor(uv * vec2(ratio, 1.0) * GRAINS);
  float r1 = hash12(gid);
  float r2 = hash12(gid + 17.3);
  float r3 = hash12(gid + 41.7);

  // the sand here came from the level f * k: one Newton step along the gradient,
  // softly limited where the plate is nearly flat; k stops growing once the lines have
  // formed, so the two sides of a thinning line do not split apart
  float k = 3.2 / max(w, lineWidth);
  vec2 d = g / gl2 * (clamp(f * k, -2.0, 2.0) - f);
  d *= smoothstep(0.0, 0.1, t) / (1.0 + length(d) / 0.1);
  vec2 jit = (vec2(r1, r2) - 0.5) * 0.004 * shake * sin(t * 48.0 + r1 * 6.28);
  vec4 sand = getFromColor(mirror(uv + (d + jit) / toPlate));

  // evens out the line width where the plate barely moves, relative to its typical slope
  float gn = sqrt(gl2);
  float even = mix(1.0, clamp(gn / (2.06 * length(vec2(modeX, modeY))), 0.45, 1.6), gather);
  float s = abs(f) / max(w * even, 1e-4);
  // the pile -(f / w)^2 lit from the top left, its slope taken relative to the line width
  float lit = dot(min(s, 1.2) * sign(f) * g / gn, vec2(-0.7071, 0.7071)) * 0.3;
  float relief = smoothstep(0.08, 0.4, t);
  sand.rgb *= 1.0 + shake * (r1 - 0.5) * 0.14 + relief * lit;

  float hop = smoothstep(0.6, 0.97, t);
  float thr = 0.72 + 0.4 * r2;
  float a = (1.0 - smoothstep(thr - 0.06, thr + 0.06, s)) * step(hop, r3 * 0.9 + 0.05);

  vec4 plate = getToColor(uv);
  float sh = (1.0 - smoothstep(1.0, 1.7, s)) * 0.3 * gather * (1.0 - hop);
  plate.rgb *= 1.0 - sh;
  return mix(plate, sand, a);
}
