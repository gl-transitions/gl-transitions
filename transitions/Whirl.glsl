// Author: gre
// License: MIT
// Description: Squares open one inside another out of the middle of the frame, each turned a little more than the last and showing one of the two images in turn, as small and as turned as the square itself, so their corners wind into spiral arms; they keep growing until the last one straightens up into the whole incoming image
// Tags: squares, spiral, nested, rotate, zoom, geometric

// @range(1, 11, 2) Number of squares, an odd number
uniform float squares; // = 7.0
// @range(-0.6, 0.6) How much each square turns from the one around it, in radians
uniform float twist; // = 0.3
// @range(0, 1) Strength of the shadow that each square casts on the one around it
uniform float shadow; // = 0.5

const int MAXN = 11;
// half side of a square that is born
const float SEED = 0.07;
// size of a square, relative to the frame's half diagonal, around which it straightens up, and the softness of that
const float FULL = 0.5;
const float SOFT = 0.65;

vec2 mirrored(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// spot: where in the image, odd: whether the square shows the outgoing one
vec4 picture(vec3 spot) {
  vec2 st = mirrored(spot.xy / vec2(ratio, 1.0) + 0.5);
  return premultiplied(spot.z > 0.5 ? getFromColor(st) : getToColor(st));
}

vec4 transition(vec2 uv) {
  float n = 2.0 * floor(clamp(squares, 1.0, 11.0) * 0.5) + 1.0;
  vec2 P = (uv - 0.5) * vec2(ratio, 1.0);
  float R = 0.5 * length(vec2(ratio, 1.0)) + 0.02;
  // ratio of a square to the one it is inscribed in, when turned by bend
  float bend = clamp(twist, -0.75, 0.75);
  float gap = log(cos(bend) + abs(sin(bend))) + 0.1;
  float t = progress * (1.5 - 0.5 * progress);
  float z = (gap * (n - 1.0) + log(1.0 + R / SEED)) * t;
  vec3 top = vec3(P, 1.0);
  vec3 under = top;
  float cover = 1.0;
  float shade = 1.0;
  bool parent = true;
  for (int i = 0; i < MAXN; i++) {
    float k = float(i);
    float h = SEED * (exp(max(z - gap * k, 0.0)) - 1.0);
    if (k >= n || h <= 1e-4) break;
    float u = log(h / (FULL * R));
    // smooth minimum of u and 0, exactly 0 once the square spans the frame
    float v = u < -SOFT ? u : u < SOFT ? -(SOFT - u) * (SOFT - u) / (4.0 * SOFT) : 0.0;
    float a = bend / gap * v;
    vec2 q = vec2(cos(a) * P.x + sin(a) * P.y, cos(a) * P.y - sin(a) * P.x);
    float d = h - max(abs(q.x), abs(q.y));
    float m = clamp(d / 0.0025, 0.0, 1.0);
    if (m > 0.0) {
      under = top;
      // a tiny square only shows a part of the picture, which would alias if it were all in there
      top = vec3(q * exp(-max(v, -2.2)), mod(k, 2.0));
      cover = m;
      shade = 1.0;
    }
    if (parent || m > 0.0) shade *= 1.0 - 0.45 * shadow * exp(min(d, 0.0) / (0.22 * h)) * (1.0 - m);
    parent = m > 0.0;
  }
  vec4 col = mix(picture(under), picture(top), cover);
  col.rgb *= shade;
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
