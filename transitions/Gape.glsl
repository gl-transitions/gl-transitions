// Author: gre
// License: MIT
// Description: The outgoing image is a rubber sheet with a short slit, pulled from its left and right sides: the slit gapes into an almond and then a wide oval hole, the picture around it stretching along the rim and squeezed across it, until the hole has swallowed the frame and shows the whole incoming image
// Tags: elastic, stretch, hole, rubber, physical

// @param Where the slit is cut
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0.05, 0.4) Length of the slit, in frame heights
uniform float slit; // = 0.22

// width over height of the hole once fully pulled open
const float WIDE = 1.8;

// signed distance to the rim of the ellipse of half axes A, in frame heights, from the gradient of |p / A|
float rim(vec2 p, vec2 A) {
  vec2 q = p / A;
  float r = length(q);
  vec2 n = r > 0.0 ? q / r : vec2(1.0, 0.0);
  return (r - 1.0) / length(n / A);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 c = (center - 0.5) * vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0) - c;
  float open = smoothstep(0.03, 0.55, t);
  // the hole's half height when it just contains the farthest corner, with a margin for the rim
  float reach = 1.04 * length(vec2((0.5 * ratio + abs(c.x)) / WIDE, 0.5 + abs(c.y)));
  float ay = mix(0.5 * slit * smoothstep(0.0, 0.12, t), reach, pow(t, 2.2)) + 1e-4;
  // pulled sideways, the slit gapes wider than it is long
  float ax = ay * mix(0.04, WIDE, open);
  vec2 A = vec2(ax, ay);

  // confocal ellipses around the hole: the rim comes from the segment between the foci and each
  // ring of rubber slides out by exactly the area the hole gained, smooth even around a thin slit
  bool tall = ay > ax;
  vec2 pp = tall ? p.yx : p;
  float M = max(ax, ay), m = min(ax, ay);
  float F2 = M * M - m * m;
  float sq = dot(pp, pp) - F2;
  float D = sqrt(sq * sq + 4.0 * pp.y * pp.y * F2);
  // b squared of the confocal ellipse through pp, written without cancellation on both sides
  float b2 = sq >= 0.0 ? 0.5 * (sq + D) : 2.0 * pp.y * pp.y * F2 / max(D - sq, 1e-8);
  float b = sqrt(b2), a = sqrt(b2 + F2);
  float k = max(a * b - M * m, 0.0);
  float b02 = 2.0 * k * k / max(F2 + sqrt(F2 * F2 + 4.0 * k * k), 1e-8);
  vec2 pp0 = pp * vec2(sqrt(b02 + F2) / max(a, 1e-6), sqrt(b02) / max(b, 1e-6));
  vec4 from = getFromColor(((tall ? pp0.yx : pp0) + c) / vec2(ratio, 1.0) + 0.5);

  float edge = rim(p, A);
  float grown = smoothstep(0.0, 0.02, ax);
  // the padded hole stays shut until the slit has a visible length
  float cover = max(smoothstep(0.0, 0.003 * grown + 1e-6, edge), 1.0 - smoothstep(0.0, 0.01, t));
  float lip = grown * exp(-max(edge, 0.0) / 0.006);
  float up = normalize(p / A + vec2(0.0, 1e-6)).y;
  from.rgb *= 1.0 - 0.3 * lip * smoothstep(-0.2, 0.6, up);
  from.rgb += 0.18 * lip * from.a * (1.0 - from.rgb) * smoothstep(0.0, 0.6, -up);
  from.rgb *= 1.0 - 0.12 * grown * exp(-max(edge, 0.0) / 0.05) * smoothstep(0.0, 0.5, up);

  // lit from the top left, the sheet shades the incoming image just inside the top of the hole
  vec4 to = getToColor(uv);
  float depth = -rim(p - vec2(0.006, -0.01), A);
  float big = smoothstep(0.02, 0.15, min(ax, ay));
  to.rgb *= 1.0 - 0.3 * big * (1.0 - t) * (1.0 - smoothstep(0.0, 0.03, depth));
  return mix(to, from, cover);
}
