// Author: gre
// License: MIT
// Description: The outgoing image folds up like a pleated paper toward one side while the incoming one unfolds out of the other, both in 3D with lit and shadowed pleats
// Tags: fold, 3d, slide, stripes

// @range(1, 12, 1) Number of pleats in each image (a pleat is a pair of panels, one lit and one in the shade)
uniform int pleats; // = 4
// @param Direction in which the images move, snapped to its main axis (left, right, up or down): the outgoing image folds up toward it, the incoming one unfolds from the opposite side
uniform vec2 direction; // = vec2(-1.0, 0.0)
// @range(0, 1) Contrast between the lit and the shaded panels
uniform float shading; // = 0.7
// @range(0, 3) Amount of perspective: the valleys between the pleats recede
uniform float perspective; // = 1.5
// @color Color seen around the folded images, where the valleys recede
uniform vec4 backColor; // = vec4(0.0, 0.0, 0.0, 1.0)

// light from the front and the side: its sideways and front components
const float LIGHT_SIDE = 0.55;
const float LIGHT_FRONT = 0.835;
// width of the anti-aliased folds and edges, in frame heights
const float EDGE = 0.0015;

// brightness of a panel folded by angle (c, s) = (cos, sin), facing the light (sign 1) or away (-1)
float panelLight(float c, float s, float facing) {
  float lambert = (c * LIGHT_FRONT + facing * s * LIGHT_SIDE) / LIGHT_FRONT;
  return mix(1.0, clamp(lambert, 0.08, 1.25), shading);
}

// one folded image: f is the position along it (0 to 1, from its anchored side), c the visible part
// of its length (cos of the fold angle), len its length and b the position across it, in frame heights
vec4 pleated(float f, float c, float len, float b, float bLen, bool incoming, bool flipA, bool vertical) {
  float m = 2.0 * float(pleats > 1 ? pleats : 1);
  float s = sqrt(max(1.0 - c * c, 0.0));
  float u = f * m;
  // f = 1 is the end of the last panel, not the start of one more
  float panel = min(floor(u), m - 1.0);
  float fu = u - panel;
  // the ridges (odd boundaries) stay in the frame's plane, the valleys (even ones) recede
  float tri = 1.0 - abs(mod(u, 2.0) - 1.0);
  float panelLen = len / m;
  float z = panelLen * s * (1.0 - tri);
  // farther parts look smaller
  float scale = 1.0 / (1.0 + perspective * z);
  float bb = (b - 0.5 * bLen) / scale / bLen + 0.5;
  // soft top and bottom edges while folded (sharp when flat, to keep the first and last frames exact)
  float edge = EDGE * min(1.0, 20.0 * s * c) + 1e-6;
  float cover = clamp(min(bb, 1.0 - bb) * bLen * scale / edge, 0.0, 1.0);
  float a = flipA ? 1.0 - f : f;
  vec2 st = clamp(vertical ? vec2(bb, a) : vec2(a, bb), 0.0, 1.0);
  vec4 img = incoming ? getToColor(st) : getFromColor(st);
  // even panels face the light, odd ones turn away; blend across each fold over a pixel or so
  float facing = mod(panel, 2.0) < 0.5 ? 1.0 : -1.0;
  float toEdge = min(fu, 1.0 - fu) * panelLen * c;
  float k = 0.5 + 0.5 * clamp(toEdge / EDGE, 0.0, 1.0);
  float light = mix(panelLight(c, s, -facing), panelLight(c, s, facing), k);
  // a touch of shade deep in the valleys
  float valley = 1.0 - tri;
  light *= 1.0 - 0.4 * shading * s * valley * valley;
  return mix(backColor, vec4(img.rgb * light, img.a), cover);
}

vec4 transition(vec2 uv) {
  bool vertical = abs(direction.y) > abs(direction.x);
  bool positive = vertical ? direction.y > 0.0 : direction.x > 0.0;
  // a: along the motion, 0 on the side the outgoing image folds up toward; b: across it
  float a = vertical ? uv.y : uv.x;
  if (positive) a = 1.0 - a;
  float b = vertical ? uv.x : uv.y;
  float len = vertical ? 1.0 : ratio;
  float bLen = vertical ? ratio : 1.0;

  float p = progress;
  float e = p * p * (3.0 - 2.0 * p);
  e = mix(p, e, 0.8);
  // visible part of each image's length
  float cFrom = 1.0 - e;
  float cTo = e;
  if (a < cFrom || cTo <= 0.0) {
    // the outgoing image, anchored on its side
    return pleated(a / cFrom, cFrom, len, b * bLen, bLen, false, positive, vertical);
  }
  // the incoming image, anchored on the opposite side
  return pleated(1.0 - (1.0 - a) / cTo, cTo, len, b * bLen, bLen, true, positive, vertical);
}
