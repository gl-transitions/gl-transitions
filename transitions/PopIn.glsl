// Author: gre
// License: MIT
// Description: The incoming image pops in as a rounded card over the outgoing one, with an elastic overshoot: too big, a bit small, then it settles into the full frame as its corners square off
// Tags: pop, scale, zoom, elastic, bounce, shadow

// @param Point of the frame the incoming image pops from
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 1.5) How far the card overshoots (too big, then a bit small) before it settles
uniform float bounce; // = 1.0
// @range(0, 0.5) Corner radius of the card while it pops, relative to its shorter side
uniform float corner; // = 0.12
// @range(0, 1) Darkness of the drop shadow the card casts on the outgoing image
uniform float shadow; // = 0.5

const float PI = 3.141592653589793;

// signed distance to a rounded box of half size b and corner radius r
float roundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec4 transition(vec2 uv) {
  float t = progress;
  // scale of the card: an ease-out, plus a damped spring that overshoots and lands exactly at t = 1
  float easeOut = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
  float spring = 1.0 - exp(-1.5 * t) * cos(2.5 * PI * t) * (1.0 - t);
  float s = mix(easeOut, spring, bounce);

  // the card is the incoming frame scaled by s around the center, in aspect-corrected space
  vec2 asp = vec2(ratio, 1.0);
  float side = min(ratio, 1.0);
  vec2 cardCenter = center + (0.5 - center) * s;
  vec2 halfSize = 0.5 * s * asp;
  float r = corner * s * side * (1.0 - t);
  float aa = 0.002;
  // the edge is pushed out by one antialiasing width, so at t = 1 the card covers the whole frame
  float d = roundedBox((uv - cardCenter) * asp, halfSize, r) - aa;
  float cover = clamp(0.5 - d / aa, 0.0, 1.0) * smoothstep(0.0, 0.08, t);

  // drop shadow on the outgoing image, offset down and blurred, growing with the card
  float k = min(s, 1.0) * side;
  float blur = 0.05 * k + 1e-4;
  vec2 offset = vec2(0.0, -0.03 * k);
  float ds = roundedBox((uv - cardCenter - offset) * asp, halfSize, r);
  float shade = shadow * (1.0 - smoothstep(-blur, blur, ds)) * smoothstep(0.0, 0.15, t);

  vec4 a = getFromColor(uv);
  // the shadow darkens the outgoing image, it does not change its alpha (no shadow on transparent areas)
  a.rgb *= 1.0 - shade;
  // clamped: only the antialiased rim, one pixel or two outside the card, reads past the edge
  vec4 b = getToColor(clamp((uv - center) / max(s, 1e-4) + center, 0.0, 1.0));
  // blend premultiplied, then back to straight alpha
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), cover);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
