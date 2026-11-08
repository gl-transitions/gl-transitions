// Author: gre
// License: MIT
// Description: The frame splits into slanted comic-book panels with gutters and ink borders; one after another in reading order, each panel lifts off the page with a zoom kick and a drop shadow and punches over to the incoming image, then the gutters close up over the full incoming image
// Tags: comic, panels, grid, zoom

// @range(0, 0.1) Width of the gutters between the panels, as a part of the frame's height
uniform float gutter; // = 0.03
// @color Color of the gutters and of the page's margin
uniform vec4 gutterColor; // = vec4(1.0, 1.0, 1.0, 1.0)
// @color Color of the ink borders around the panels
uniform vec4 borderColor; // = vec4(0.0, 0.0, 0.0, 1.0)
// @range(0, 100, 1) Changes the layout of the panels
uniform float seed; // = 0.0

const float PI = 3.141592653589793;
// width of the ink borders, as a part of the frame's height
const float INK = 0.005;
// width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0012;
// part of the transition taken by each panel's punch
const float PUNCH = 0.3;
// the first panel's punch starts at START, the last one ends at END
const float START = 0.05;
const float END = 0.97;
// number of spikes of the burst that brings the incoming image into a panel
const float SPIKES = 11.0;

float hash(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// number of panels in row r (0 is the top row)
float cols(float r) {
  float h = hash(vec2(r * 7.0 + 3.0, seed * 1.37 + 11.0));
  float n = h < 0.15 ? 1.0 : (h < 0.6 ? 2.0 : 3.0);
  // the middle row is never a single panel, a narrow frame takes at most 2 panels per row
  if (r == 1.0) n = max(n, 2.0);
  if (ratio < 0.8) n = min(n, 2.0);
  return n;
}

// signed distance of p (x from 0 to ratio, y from 0 at the top to 1) below the gutter k between the rows
// (0 is the top of the frame, 3 its bottom)
float rowDist(float k, vec2 p) {
  if (k < 0.5) return p.y;
  if (k > 2.5) return p.y - 1.0;
  float y = (k + (hash(vec2(k * 5.0 + 1.0, seed * 1.37)) - 0.5) * 0.35) / 3.0;
  float s = (hash(vec2(k * 9.0 + 4.0, seed * 1.37 + 5.0)) - 0.5) * 0.24;
  return (p.y - y - s * (p.x / ratio - 0.5)) / sqrt(1.0 + s * s / (ratio * ratio));
}

// signed distance of p right of the gutter j of row r, which has n panels (0 is the left of the frame, n its right)
float colDist(float r, float j, float n, vec2 p) {
  if (j < 0.5) return p.x;
  if (j > n - 0.5) return p.x - ratio;
  float x = (j + (hash(vec2(r * 3.0 + j * 13.0, seed * 1.37 + 2.0)) - 0.5) * 0.45) / n;
  float s = (hash(vec2(r * 11.0 + j * 5.0, seed * 1.37 + 7.0)) - 0.5) * 0.5;
  return (p.x - ratio * (x + s * (p.y - 0.5))) / sqrt(1.0 + ratio * ratio * s * s);
}

// signed distance to the edges of panel c of row r, positive inside
float panelDist(float r, float c, float n, vec2 p) {
  return min(min(rowDist(r, p), -rowDist(r + 1.0, p)), min(colDist(r, c, n, p), -colDist(r, c + 1.0, n, p)));
}

// a point inside panel c of row r, as far from its top as from its bottom and from its left as from its right
vec2 panelCenter(float r, float c, float n) {
  // the sums of the distances to the opposite edges are linear: find where they are 0
  float y0 = rowDist(r, vec2(0.5 * ratio, 0.0)) + rowDist(r + 1.0, vec2(0.5 * ratio, 0.0));
  float y1 = rowDist(r, vec2(0.5 * ratio, 1.0)) + rowDist(r + 1.0, vec2(0.5 * ratio, 1.0));
  float y = y0 / (y0 - y1);
  float x0 = colDist(r, c, n, vec2(0.0, y)) + colDist(r, c + 1.0, n, vec2(0.0, y));
  float x1 = colDist(r, c, n, vec2(1.0, y)) + colDist(r, c + 1.0, n, vec2(1.0, y));
  return vec2(x0 / (x0 - x1), y);
}

// the panel's punch, 0 to 1: panel k of the n panels of the page, in reading order
float panelTime(float k, float total) {
  float t0 = START + (END - START - PUNCH) * k / max(total - 1.0, 1.0);
  return clamp((progress - t0) / PUNCH, 0.0, 1.0);
}

// how high the panel is lifted off the page: a quick rise, a slower settle
float lift(float t) {
  float u = 1.0 - (1.0 - t) * (1.0 - t);
  return sin(PI * u);
}

// the panel's image at the page point p: the outgoing one until the incoming one bursts out of the panel's center
// in a jagged star with an ink outline
vec4 panelImage(vec2 p, vec2 center, float t) {
  float k = lift(t);
  // the image zooms in with the kick, then settles
  vec2 q = center + (p - center) / (1.0 + 0.1 * k);
  vec2 uv = vec2(q.x / ratio, 1.0 - q.y);
  if (t <= 0.0) return getFromColor(uv);
  if (t >= 1.0) return getToColor(uv);
  vec2 v = p - center;
  float a = (atan(v.y, v.x + 1e-6) + PI) / (2.0 * PI) * SPIKES + center.x * 7.0;
  float i = floor(a);
  // the spikes, of uneven lengths
  // (the spike index wraps around so that the star has no seam where the angle wraps)
  float spike = (1.0 - abs(2.0 * (a - i) - 1.0)) * (0.5 + 0.5 * hash(vec2(mod(i, SPIKES), center.y * 13.0 + seed)));
  // large enough to cover the widest panel, a whole row of a wide frame
  float burst = 1.5 * max(1.0, ratio / 1.8) * smoothstep(0.06, 0.42, t);
  float d = length(v) - burst * (0.62 + 0.38 * spike);
  float w = 1.4 * INK;
  vec4 c = mix(getToColor(uv), borderColor, smoothstep(-w - EDGE, -w + EDGE, d));
  return mix(c, getFromColor(uv), smoothstep(-EDGE, EDGE, d));
}

// the panel drawn over color: its gutter edge at g from its edges, its ink border inside it
vec4 drawPanel(vec4 color, vec4 img, float d, float g, float ink, float fade) {
  vec4 c = mix(borderColor, img, mix(1.0, smoothstep(g + ink - EDGE, g + ink + EDGE, d), fade));
  return mix(color, c, mix(1.0, smoothstep(g - EDGE, g + EDGE, d), fade));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  vec2 p = vec2(uv.x * ratio, 1.0 - uv.y);

  // the gutters open at the start and close over the incoming image at the end
  float open = smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  float g = 0.5 * gutter * open;
  float ink = INK * open;
  // the edges come in gently instead of popping in at half coverage
  float fade = clamp(open * 6.0, 0.0, 1.0);

  float n0 = cols(0.0);
  float n1 = cols(1.0);
  float n2 = cols(2.0);
  float total = n0 + n1 + n2;

  // the panel under the point, on the page
  float r = rowDist(1.0, p) < 0.0 ? 0.0 : (rowDist(2.0, p) < 0.0 ? 1.0 : 2.0);
  float n = r == 0.0 ? n0 : (r == 1.0 ? n1 : n2);
  float c = colDist(r, 1.0, n, p) < 0.0 ? 0.0 : (colDist(r, 2.0, n, p) < 0.0 || n < 2.5 ? 1.0 : 2.0);
  c = min(c, n - 1.0);
  float first = r == 0.0 ? 0.0 : (r == 1.0 ? n0 : n0 + n1);
  float t = panelTime(first + c, total);

  vec4 color = gutterColor;
  if (t <= 0.0 || t >= 1.0) {
    color = drawPanel(color, panelImage(p, panelCenter(r, c, n), t), panelDist(r, c, n, p), g, ink, fade);
  }

  // the panels lifted off the page, the later ones on top: at most 4 of them punch at once
  float spacing = (END - START - PUNCH) / max(total - 1.0, 1.0);
  // (with a margin, so that a panel at the very end of its punch is not missed to rounding)
  float kFirst = floor((progress - START - PUNCH) / spacing - 0.01) + 1.0;
  for (int i = 0; i < 4; i++) {
    float pk = kFirst + float(i);
    if (pk < 0.0 || pk > total - 0.5) continue;
    float pt = panelTime(pk, total);
    if (pt <= 0.0 || pt >= 1.0) continue;
    float pr = pk < n0 ? 0.0 : (pk < n0 + n1 ? 1.0 : 2.0);
    float pn = pr == 0.0 ? n0 : (pr == 1.0 ? n1 : n2);
    float pc = pk - (pr == 0.0 ? 0.0 : (pr == 1.0 ? n0 : n0 + n1));
    float k = lift(pt);
    vec2 center = panelCenter(pr, pc, pn);
    float s = 1.0 + 0.08 * k;
    // its soft shadow on the page, down and to the right
    vec2 sq = center + (p - vec2(0.012, 0.018) * k - center) / s;
    float sd = panelDist(pr, pc, pn, sq) - g;
    color.rgb *= 1.0 - 0.4 * k * fade * smoothstep(-0.02, 0.01, sd);
    vec2 q = center + (p - center) / s;
    color = drawPanel(color, panelImage(q, center, pt), panelDist(pr, pc, pn, q), g, ink, 1.0);
  }
  return color;
}
