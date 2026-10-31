// Author: gre
// License: MIT
// Description: The outgoing image is cut into paper strips that drop away at uneven speeds, tilting as they fall, revealing the incoming image
// Tags: slices, stripes, vertical, shadow

// @range(4, 60, 1) Number of strips
uniform int strips; // = 20
// @range(0, 0.8) Spread of the strips' start times, as a part of the transition
uniform float stagger; // = 0.4
// @range(0, 0.3) Largest tilt of a falling strip, in radians
uniform float tilt; // = 0.1
// @range(0, 1) Darkness of the strips' cut edges and of their shadow
uniform float shadow; // = 0.5

// a deterministic random value in [0, 1) for each strip
float hash (float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

vec4 transition (vec2 uv) {
  float n = float(strips);
  float w = ratio / n; // strip width, in frame heights
  vec2 q = vec2(uv.x * ratio, uv.y);
  vec4 color = getToColor(uv);
  float cover = -1.0;
  float shade = 0.0;
  // narrow strips tilt less, so that they only reach over their neighbours
  float maxTilt = min(tilt, 2.0 * w);
  for (int d = -3; d <= 3; d++) {
    float i = floor(uv.x * n) + float(d);
    if (i < 0.0 || i > n - 1.0) continue;
    // about one strip in five starts right away
    float delay = stagger * max(0.0, 1.25 * hash(i + 1.0) - 0.25);
    float speed = 1.0 + 0.5 * hash(i + 71.0);
    float t = clamp((progress - delay) / (1.0 - delay), 0.0, 1.0);
    // a pull then a fall that speeds up, long enough to leave the frame
    float fall = (0.4 * t + 0.6 * t * t) * (1.0 + w * (0.5 + tilt)) * speed;
    float angle = maxTilt * (2.0 * hash(i + 37.0) - 1.0) * t;
    // the strips are cut apart as they start moving
    float lift = min(1.0, 8.0 * t);
    float gap = 0.06 * w * lift;
    // position in the strip's own frame, relative to its center
    vec2 v = q - vec2((i + 0.5) * w, 0.5 - fall);
    float ca = cos(angle), sa = sin(angle);
    vec2 l = vec2(ca * v.x + sa * v.y, ca * v.y - sa * v.x);
    vec2 edge = vec2(0.5 * w - gap, 0.5) - abs(l);
    // a soft shadow, cast down and right by the moving strip
    vec2 so = abs(l - lift * vec2(0.15 * w, -0.25 * w)) - vec2(0.5 * w - gap, 0.5);
    shade = max(shade, lift * (1.0 - smoothstep(0.0, 0.5 * w, max(so.x, so.y))));
    if (min(edge.x, edge.y) >= 0.0 && fall > cover) {
      vec2 p = vec2((i + 0.5) * w + l.x, 0.5 + l.y);
      vec4 img = getFromColor(vec2(p.x / ratio, p.y));
      // darker cut edges
      float cut = lift * (1.0 - smoothstep(0.0, 0.25 * w, edge.x));
      color = vec4(img.rgb * (1.0 - 0.5 * shadow * cut), img.a);
      cover = fall;
    }
  }
  if (cover < 0.0) {
    color = vec4(color.rgb * (1.0 - 0.6 * shadow * shade), color.a);
  }
  return color;
}
