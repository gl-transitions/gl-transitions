// Author: gre
// License: MIT
// Description: Every part of the outgoing image is drawn toward one of fourteen drifting points, so the image stretches into large soft-cornered fields of flat color edged with the squeezed rest of the picture; field by field the colors turn to the incoming image's, then the fields let go and it spreads back
// Tags: fields, flat, warp, organic, cells, abstract

// @range(20, 120) How crisp the fields get
uniform float crispness; // = 70.0
// @range(0, 0.4) How far the fields travel, in frame heights
uniform float travel; // = 0.2

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * asp;
  float k = smoothstep(0.0, 0.42, progress) * (1.0 - smoothstep(0.58, 1.0, progress));
  vec2 sum = vec2(0.0);
  float total = 0.0;
  float late = 0.0;
  for (int i = 0; i < 14; i++) {
    float f = float(i);
    vec2 h = (fract(vec2(0.754878, 0.569840) * f + 0.3) - 0.5) * asp * 1.02;
    float a = 6.0 * (progress - 0.5) * (mod(f, 2.0) * 2.0 - 1.0) + f * 2.0;
    vec2 d = abs(p - h - travel * vec2(cos(a), sin(a)));
    float w = exp(-crispness * k * (max(d.x, d.y) * 0.6 + 0.4 * length(d)));
    sum += h * w;
    late += w * smoothstep(0.0, 0.16, progress - 0.32 - 0.2 * fract(f * 0.618));
    total += w;
  }
  // each pixel takes the image at the weighted mean of the points, so a field shows its point's color
  vec2 q = mix(p, sum / total, k) / asp + 0.5;
  q = 1.0 - abs(1.0 - mod(q, 2.0));
  return mix(getFromColor(q), getToColor(q), smoothstep(0.0, 1.0, late / total));
}
