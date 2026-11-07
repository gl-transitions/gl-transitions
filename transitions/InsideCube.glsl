// Author: gre
// License: MIT
// Description: The camera stands inside a cube: the outgoing image covers the wall in front of it and the view turns toward the next inner wall, so the outgoing image swings away in perspective as the incoming one turns into view, the walls darkening into the shaded inner corner between them
// Tags: 3d, cube, rotate, perspective, directional

// @param Direction the view turns toward, snapped to its main axis (left, right, up or down): the incoming image is on the wall on that side
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(60, 120) Field of view along the turn, in degrees: at 90 the camera stays at the center of the cube, a wider view makes the walls recede more
uniform float fov; // = 90.0
// @range(0, 1) How much the walls darken as they turn away, and the shadow in the inner corners of the cube
uniform float shading; // = 0.6
// @color Color of the other faces of the cube, seen where the two walls leave the frame uncovered during the turn
uniform vec4 background; // = vec4(0.09, 0.09, 0.1, 1.0)

const float PI = 3.141592653589793;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.002;

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// shadow of a concave edge of the cube, at a distance dist from it
float cornerShadow(float dist, float size) {
  float k = 1.0 - smoothstep(0.0, size, dist);
  return k * k;
}

// the image on a wall at the point l of the wall, in frame heights from its center (l.x along
// the turn, l.y across), premultiplied; s and vertical undo the mirroring and the swap of axes
// that transition() applies to the frame coordinates
vec4 wallColor(vec2 l, bool incoming, bool vertical, float s) {
  vec2 h = vec2(l.x * s, l.y);
  vec2 p = vertical ? h.yx : h;
  vec2 st = clamp(p / vec2(ratio, 1.0) + 0.5, 0.0, 1.0);
  return premultiply(incoming ? getToColor(st) : getFromColor(st));
}

vec4 transition(vec2 uv) {
  bool vertical = abs(direction.y) > abs(direction.x);
  float s = (vertical ? direction.y : direction.x) < 0.0 ? -1.0 : 1.0;
  // q.x: along the turn, toward the incoming wall; q.y: across; in frame heights
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  vec2 q = vertical ? p.yx : p;
  q.x *= s;
  // half sizes of a wall along and across the turn
  float A = vertical ? 0.5 : 0.5 * ratio;
  float B = vertical ? 0.5 * ratio : 0.5;
  // focal length: a wall exactly fills the frame when seen square from that distance
  // (below about 53 degrees the camera would stand outside the cube)
  float F = A / tan(radians(clamp(fov, 55.0, 170.0)) * 0.5);

  float e = smoothstep(0.0, 1.0, progress);
  float th = 0.5 * PI * e;
  float c = cos(th);
  float sn = sin(th);
  float amount = max(sin(PI * e), 0.0); // 0 at both ends, so the images are untouched there
  float aa = EDGE * min(1.0, 40.0 * amount) + 1e-6;
  float shadow = shading * min(1.0, 4.0 * amount);

  // in the plane of the turn (a: along, z: depth), the outgoing wall is z = F, a in [-A, A],
  // the incoming wall is a = A, z in [F - 2A, F]; the camera starts in front of the center of
  // the first one and ends in front of the center of the second one
  vec2 cam = (A - F) * e * vec2(1.0, -1.0);
  vec2 d = vec2(q.x * c + F * sn, F * c - q.x * sn);

  // the inner corner between the two walls projects to a line across the frame
  vec2 P = vec2(A, F) - cam;
  float sc = F * (P.x * c - P.y * sn) / max(P.x * sn + P.y * c, 1e-6);

  // outgoing wall
  float tf = d.y > 1e-6 ? (F - cam.y) / d.y : 1e6;
  float af = cam.x + tf * d.x;
  vec2 lf = vec2(af, q.y * tf);
  // incoming wall
  float ti = d.x > 1e-6 ? (A - cam.x) / d.x : 1e6;
  float ai = (F - A) - (cam.y + ti * d.y);
  vec2 li = vec2(ai, q.y * ti);

  // each wall darkens as it turns away from the view, and toward the concave edges
  float size = 0.8 * min(A, B);
  float edgeF = cornerShadow(A - af, size) + 0.5 * cornerShadow(B - abs(lf.y), size);
  float edgeI = cornerShadow(ai + A, size) + 0.5 * cornerShadow(B - abs(li.y), size);
  float shadeF = (1.0 - shading * 0.8 * (1.0 - c)) * (1.0 - 0.7 * shadow * min(edgeF, 1.0));
  float shadeI = (1.0 - shading * 0.8 * (1.0 - sn)) * (1.0 - 0.7 * shadow * min(edgeI, 1.0));

  // how much of the pixel each wall covers, from distances on screen in frame heights: split at
  // the corner line, cut across by the edges of the walls (lb = q.y * t), and at their far
  // edges (along the wall, a moves F * t / d.depth times faster than q.x)
  float wF = clamp(0.5 + (sc - q.x) / aa, 0.0, 1.0);
  float covF = wF * clamp(0.5 + (B / tf - abs(q.y)) / aa, 0.0, 1.0)
    * clamp(0.5 + (af + A) * d.y / (tf * F * aa), 0.0, 1.0);
  float covI = (1.0 - wF) * clamp(0.5 + (B / ti - abs(q.y)) / aa, 0.0, 1.0)
    * clamp(0.5 + (A - ai) * d.x / (ti * F * aa), 0.0, 1.0);
  // only sample the walls that show in this pixel
  vec4 colF = covF > 0.0 ? wallColor(lf, false, vertical, s) : vec4(0.0);
  vec4 colI = covI > 0.0 ? wallColor(li, true, vertical, s) : vec4(0.0);
  colF.rgb *= shadeF;
  colI.rgb *= shadeI;

  // the other faces of the cube, with the same shadow along their edges with the two walls
  vec4 bg = premultiply(background);
  float cov = covF + covI;
  if (cov < 1.0) {
    // where the ray meets the floor or the ceiling, never beyond the walls
    float tb = min(B / max(abs(q.y), 1e-6), min(tf, ti));
    vec2 fl = cam + tb * d;
    float edgeB = cornerShadow(F - fl.y, size) + cornerShadow(A - fl.x, size);
    bg.rgb *= 1.0 - 0.5 * shadow * min(edgeB, 1.0);
  }
  vec4 col = colF * covF + colI * covI + bg * (1.0 - cov);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
