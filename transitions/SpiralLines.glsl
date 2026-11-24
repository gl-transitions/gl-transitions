// Author: gre
// License: MIT
// Description: The outgoing picture is redrawn as one continuous spiral line winding inward on paper, thick in its darks and thin in its lights; the line thins to a hairline spiral from the center out, swells again into the shapes of the incoming picture and spreads back into the full photo
// Tags: spiral, line-art, graphic, stylized, math

// @range(15, 80) Number of strokes of the line across the frame height
uniform float strokes; // = 44.0
// @range(0, 8) Number of turns the spiral winds
uniform float winding; // = 4.0
// @color Color of the line
uniform vec4 ink; // = vec4(0.09, 0.1, 0.17, 1.0)
// @color Color of the paper
uniform vec4 paper; // = vec4(0.96, 0.94, 0.89, 1.0)

const float TAU = 6.283185307;

vec4 weighted(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

float shade(vec4 c) {
  return clamp(1.1 * (1.0 - dot(c.rgb, vec3(0.299, 0.587, 0.114))) - 0.04, 0.0, 1.0) * c.a;
}

// half width of the stroke whose center passes at radius rc, at the angle of the unit vector dir
float strokeWidth(vec2 dir, float rc, float n, float style, float aa) {
  vec2 asp = vec2(ratio, 1.0);
  float t = progress - 0.1 * (rc / (0.5 * length(asp)) - 0.5);
  float dark = 0.0;
  for (int i = 0; i < 5; i++) {
    float a = float(i) - 2.0;
    // along the stroke, the outer two across it
    vec2 o = abs(a) > 1.5 ? dir * a * 0.1 : vec2(-dir.y, dir.x) * a * 0.3;
    vec2 cuv = clamp((dir * max(rc, 0.0) + o / n) / asp + 0.5, 0.0, 1.0);
    dark += 0.2 * (t < 0.5 ? shade(getFromColor(cuv)) : shade(getToColor(cuv)));
  }
  // flat around t = 0.5, where the images are swapped
  float k = smoothstep(0.02, 0.21, abs(t - 0.5));
  // past 1 + aa the strokes touch and no paper is left
  return mix(1.0 + aa, mix(0.13, 0.1 + 0.8 * dark, k), style);
}

vec4 transition(vec2 uv) {
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float n = max(strokes, 1.0);
  float r = max(length(q), 1e-4);
  // a +-PI flip on the seam is one full turn, which fract removes
  float th = abs(q.x) + abs(q.y) < 1e-5 ? 0.0 : atan(q.y, q.x);
  float f = fract(r * n - th / TAU + winding * smoothstep(0.0, 1.0, progress)) - 0.5;
  float d = 2.0 * abs(f);

  float style = min(1.0, min(progress, 1.0 - progress) / 0.24);
  style *= 2.0 - style;
  float aa = n / 420.0;
  float rc = r - f / n;
  float w = strokeWidth(q / r, rc, n, style, aa);
  // the next turn may swell over this one's half
  float w2 = strokeWidth(q / r, rc + (f < 0.0 ? -1.0 : 1.0) / n, n, style, aa);
  float line = 1.0 - min(smoothstep(w - aa, w + aa, d), smoothstep(w2 - aa, w2 + aa, 2.0 - d));

  vec4 photo = weighted(progress < 0.5 ? getFromColor(uv) : getToColor(uv));
  vec4 stroke = mix(photo, weighted(ink), smoothstep(0.1, 0.9, style));
  vec4 o = mix(weighted(paper), stroke, line);
  return o.a > 0.0 ? vec4(o.rgb / o.a, o.a) : vec4(0.0);
}
