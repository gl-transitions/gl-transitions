// Author: gre
// License: MIT
// Description: The image twists like a ribbon around its horizontal center line, the twist travelling smoothly across its width, the outgoing image on its front and the incoming one on its back
// Tags: 3d, flip, rotate

// @range(0.1, 2) Length of the twisted section, as a part of the frame's width
uniform float spread; // = 0.8
// @range(0, 0.8) Amount of perspective: the edge turning toward the viewer grows
uniform float perspective; // = 0.4
// @range(0, 1) How much the ribbon darkens as it turns away
uniform float shading; // = 0.6
// @param Twist around the vertical center line instead, travelling from top to bottom
uniform bool vertical; // = false
// @color Color seen where the twisting ribbon leaves the frame uncovered
uniform vec4 backColor; // = vec4(0.0, 0.0, 0.0, 1.0)

const float PI = 3.141592653589793;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.002;

vec4 transition (vec2 uv) {
  // q.x: along the ribbon, the way the twist travels; q.y: across the ribbon
  vec2 q = vertical ? vec2(1.0 - uv.y, uv.x) : uv;
  // the ribbon's half width across, in frame heights
  float halfSize = vertical ? 0.5 * ratio : 0.5;
  // each line across the ribbon turns half a turn, a little later than the one before
  float t = smoothstep(0.0, 1.0, (progress * (1.0 + spread) - q.x) / spread);
  // the visible face (outgoing front, incoming back) and its angle from its rest position
  bool front = t < 0.5;
  float angle = PI * (front ? t : t - 1.0);
  float c = cos(angle);
  float s = sin(angle);
  // w: screen position across the ribbon, -1 to 1 at rest; v: the matching position on the face
  // a point v of the face goes to v * c across and v * s in depth, nearer points look bigger
  float w = 2.0 * q.y - 1.0;
  float den = c + perspective * w * s;
  if (den <= 0.0) return backColor;
  float v = w / den;
  if (abs(v) >= 1.0) return backColor;
  // soft edges while twisting (sharp at rest, to keep the first and last frames exact)
  float edge = max(EDGE * min(1.0, 20.0 * abs(s)), 1e-4);
  float top = c / (1.0 - perspective * s);
  float bottom = -c / (1.0 + perspective * s);
  float cover = clamp(min(top - w, w - bottom) * halfSize / edge, 0.0, 1.0);
  vec2 p = vec2(q.x, 0.5 + 0.5 * v);
  p = vertical ? vec2(p.y, 1.0 - p.x) : p;
  vec4 img = front ? getFromColor(p) : getToColor(p);
  // lit from the front and slightly from one side of the axis
  float lambert = clamp(c - 0.25 * s, 0.0, 1.0);
  vec4 color = vec4(img.rgb * mix(1.0 - shading, 1.0, lambert), img.a);
  return mix(backColor, color, cover);
}
