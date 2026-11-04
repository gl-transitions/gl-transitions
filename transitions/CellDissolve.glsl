// Author: gre
// License: MIT
// Description: Irregular cells, like cracked mud or soap foam, switch to the incoming image one by one, with an optional bright border glowing along the cracks between them
// Tags: dissolve, cells, voronoi, random

// @range(1, 40) Number of cells across the height of the frame
uniform float cells; // = 8.0
// @range(0, 1) Duration of each cell's switch, as a fraction of the transition (0: each cell switches at once)
uniform float smoothness; // = 0.1
// @range(0, 0.05) Width of the border along the cell edges, in frame heights (0: no border)
uniform float border; // = 0.006
// @color Color of the border
uniform vec4 borderColor; // = vec4(1.0, 0.95, 0.8, 1.0)
// @param Random seed: another value gives other cells, switching in another order
uniform float seed; // = 0.0

// half width of the antialiased edges, in frame heights
const float AA = 0.0015;

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  float n = max(cells, 1.0);
  // measured in square pixels, so the cells are not stretched
  vec2 p = uv * vec2(ratio, 1.0) * n;
  vec2 i = floor(p);
  vec2 f = p - i;
  vec2 offset = vec2(17.31, 41.97) * seed;

  // nearest cell point
  vec2 mg = vec2(0.0);
  vec2 mr = vec2(0.0);
  float md = 8.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 r = g + hash22(i + g + offset) - f;
      float d = dot(r, r);
      if (d < md) {
        md = d;
        mr = r;
        mg = g;
      }
    }
  }

  // distance to the nearest cell edge: the bisector with the closest neighbor point,
  // searched over 5x5 cells around the nearest one so that no edge is missed
  float edge = 8.0;
  for (int y = -2; y <= 2; y++) {
    for (int x = -2; x <= 2; x++) {
      vec2 g = mg + vec2(float(x), float(y));
      vec2 r = g + hash22(i + g + offset) - f;
      vec2 dr = r - mr;
      if (dot(dr, dr) > 0.00001) {
        edge = min(edge, dot(0.5 * (mr + r), normalize(dr)));
      }
    }
  }
  // in frame heights
  edge /= n;

  // the cell's own switch time, from its hash
  float h = hash22(i + mg + offset + 97.13).x;
  float w = clamp(smoothness, 0.0, 1.0);
  float start = h * (1.0 - w);
  float m = w > 0.0 ? smoothstep(start, start + w, progress) : step(start, progress);

  // mixed premultiplied, so transparent images do not bleed their color
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);

  // the cracks open at the start and close at the end
  float open = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  float bw = max(border, 0.0) * open;
  if (bw > 0.0) {
    float l = 1.0 - smoothstep(0.5 * bw - AA, 0.5 * bw + AA, edge);
    float ba = borderColor.a * l * min(1.0, bw / (2.0 * AA));
    c = vec4(borderColor.rgb * ba, ba) + c * (1.0 - ba);
  }
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
