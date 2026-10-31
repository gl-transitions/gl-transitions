// Author: gre
// License: MIT
// Description: The outgoing image tears in two along a ragged line, and the halves are pulled apart to reveal the incoming one
// Tags: split, horizontal, shadow

// @range(0, 0.3) How far the tear wanders from the middle, relative to the image height
uniform float roughness; // = 0.12
// @range(0, 0.5) How much the top of each half leans away first, so that the tear opens from the top
uniform float tilt; // = 0.1
// @range(0, 0.05) Width of the white torn edge, relative to the image height
uniform float rim; // = 0.012
// @color Color of the paper fibers on the torn edges
uniform vec4 paper; // = vec4(1.0, 0.98, 0.94, 1.0)
// @color Color of the shadow cast on the incoming image
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.35)

float tri (float x) {
  return abs(fract(x) - 0.5) - 0.25;
}

// horizontal position of the tear at height y: smooth meanders...
float meander (float y) {
  return 0.5 * ratio + roughness * (0.5 * sin(y * 4.7 + 1.3) + 0.25 * sin(y * 11.3 + 4.1));
}

// ...and sharp jags
float tear (float y) {
  return meander(y) + roughness * (0.1 * sin(y * 29.0 + 0.7) + 0.35 * tri(y * 19.0 + sin(y * 7.0)) + 0.12 * tri(y * 47.0 + 0.6 * sin(y * 13.0)));
}

// width of the torn edge along it, so that the fibers look uneven
float fibers (float y, float seed) {
  return rim * (0.7 + 0.3 * sin(y * 37.0 + seed) + 0.4 * tri(y * 83.0 + seed));
}

// the left half (or the mirrored right half) slides out, its top leaning away first:
// from a point on screen to the point of the paper (the frame edges stay covered)
vec2 unfold (vec2 q, float away, float lean) {
  return vec2(q.x + away + lean * q.y, q.y);
}

// a torn half over the background, with its fibers and an anti-aliased edge
// e: distance past the torn edge, limit: how far the fibers reach, aa: edge softness
vec4 torn (vec4 bg, vec4 col, float e, float limit, float aa) {
  vec4 c = vec4(mix(col.rgb, paper.rgb, clamp(0.5 + e / aa, 0.0, 1.0) * paper.a), col.a);
  return mix(bg, c, clamp(0.5 - (e - limit) / aa, 0.0, 1.0));
}

vec4 transition (vec2 uv) {
  float p = progress;
  float away = p * p * (0.5 * ratio + 0.1 + roughness + 2.0 * rim); // far enough to leave the frame
  float lean = tilt * p * (2.0 - p);
  float fiber = smoothstep(0.0, 0.15, p); // no torn edge on the intact image
  float aa = 0.002 * fiber + 1e-6;
  vec2 q = vec2(uv.x * ratio, uv.y);
  vec2 l = unfold(q, away, lean);
  vec2 r = unfold(vec2(ratio - q.x, q.y), away, lean);
  float el = l.x - tear(l.y); // > 0 right of the left half's torn edge
  float er = r.x - (ratio - tear(r.y)); // > 0 left of the right half's torn edge
  // soft shadow of the two halves on the incoming image, cast toward the right
  vec2 sq = q - vec2(0.01, 0.0);
  float dl = unfold(sq, away, lean).x - meander(sq.y);
  float dr = unfold(vec2(ratio - sq.x, sq.y), away, lean).x - (ratio - meander(sq.y));
  vec4 to = getToColor(uv);
  float sh = shadow.a * (1.0 - smoothstep(-0.02, 0.08, min(dl, dr)));
  vec4 c = vec4(mix(to.rgb, shadow.rgb, sh), to.a);
  // the image stops at the tear; the bare paper fibers stick out a little beyond it
  if (r.x >= 0.0) {
    c = torn(c, getFromColor(vec2(1.0 - r.x / ratio, r.y)), er, fibers(r.y, 2.0) * 1.5 * fiber, aa);
  }
  if (l.x >= 0.0) {
    c = torn(c, getFromColor(vec2(l.x / ratio, l.y)), el, fibers(l.y, 0.0) * fiber, aa);
  }
  return c;
}
