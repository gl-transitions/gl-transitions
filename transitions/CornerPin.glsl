// Author: gre
// License: MIT
// Description: The incoming image appears as a small card in the middle of the frame, then its corners are pinned out to the corners of the frame one after another, each snapping into place with a springy overshoot that skews the card in perspective, until it lies flat over the whole frame
// Tags: corner, pin, quad, perspective, snap, motion-graphics

// @range(0.05, 0.5) Size of the card before its corners are pulled out, relative to the frame
uniform float start; // = 0.2
// @range(0, 2) Overshoot of each corner as it snaps into place
uniform float overshoot; // = 1.2
// @range(0, 1) Darkness of the shadow the card casts on the outgoing image
uniform float shadow; // = 0.5

float cross2(vec2 a, vec2 b) { return a.x * b.y - a.y * b.x; }

// back-out ease: exactly 1 at x = 1, overshooting before it
float snap(float x) {
  x -= 1.0;
  float c = 1.70158 * overshoot;
  return 1.0 + (c + 1.0) * x * x * x + c * x * x;
}

vec2 corner(vec2 target, float x, float grow) {
  return mix(0.5 + (target - 0.5) * start * grow, target, snap(x));
}

// signed distance to the edge e0 -> e1 of the counterclockwise card, positive inside
float edge(vec2 p, vec2 e0, vec2 e1) {
  return cross2(e1 - e0, p - e0) / max(length(e1 - e0), 1e-6);
}

// an edge loses its softness as both its corners land, so it meets the frame border without a seam
float cover(float dist, float x0, float x1) {
  return clamp(dist / (0.002 * sqrt(1.0 - min(x0, x1)) + 1e-6) + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 asp = vec2(ratio, 1.0);
  float appear = smoothstep(0.0, 0.12, t);
  // kept above 0 so the quad never collapses to a point
  float grow = max(appear, 1e-3);
  float xa = clamp((t - 0.10) / 0.32, 0.0, 1.0), xb = clamp((t - 0.28) / 0.32, 0.0, 1.0);
  float xc = clamp((t - 0.46) / 0.32, 0.0, 1.0), xd = clamp((t - 0.64) / 0.32, 0.0, 1.0);
  vec2 a = corner(vec2(0.0, 1.0), xa, grow) * asp;
  vec2 b = corner(vec2(1.0, 1.0), xb, grow) * asp;
  vec2 c = corner(vec2(1.0, 0.0), xc, grow) * asp;
  vec2 d = corner(vec2(0.0, 0.0), xd, grow) * asp;
  vec2 p = uv * asp;

  // inverse of the projective map sending the unit square to d (0,0), c (1,0), b (1,1), a (0,1)
  vec2 s = d - c + b - a, e1 = c - b, e2 = a - b;
  float den = cross2(e1, e2);
  float g = cross2(s, e2) / den, h = cross2(e1, s) / den;
  vec3 cu = vec3(c - d + g * c, g), cv = vec3(a - d + h * a, h), c1 = vec3(d, 1.0);
  vec3 hp = vec3(p, 1.0);
  float w = dot(cross(cu, cv), hp);
  // past the card's horizon w crosses 0: keep it finite there, the card does not cover it
  w = w < 0.0 ? min(w, -1e-6) : max(w, 1e-6);
  vec2 q = vec2(dot(cross(cv, c1), hp), dot(cross(c1, cu), hp)) / w;

  float inside = min(min(cover(edge(p, d, c), xd, xc), cover(edge(p, c, b), xc, xb)),
                     min(cover(edge(p, b, a), xb, xa), cover(edge(p, a, d), xa, xd)));
  inside *= smoothstep(0.0, 0.02, t);

  float lift = 1.0 - smoothstep(0.3, 1.0, xd);
  vec2 ps = p - vec2(0.012, -0.02) * lift * grow;
  float blur = 0.025 * grow;
  float sd = min(min(edge(ps, d, c), edge(ps, c, b)), min(edge(ps, b, a), edge(ps, a, d)));
  float sh = shadow * lift * appear * smoothstep(-blur, blur, sd);

  vec4 from = getFromColor(uv);
  from.rgb *= 1.0 - sh;
  return mix(from, getToColor(clamp(q, 0.0, 1.0)), inside);
}
