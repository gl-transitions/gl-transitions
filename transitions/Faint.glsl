// Author: gre
// License: MIT
// Description: The viewer faints: the outgoing image splits into two swaying copies of itself and blurs while the edges of the view darken and close in, in two heartbeat throbs, down to a last pinpoint of light; the incoming image comes back blurred and doubled through a narrow tunnel, which widens again in throbs as the two copies drift together and lock
// Tags: eye, vignette, blur, fade

// @range(0, 0.15) How far apart the two copies drift at the peak, in frame heights
uniform float separation; // = 0.07
// @range(0, 1) How out of focus the view gets
uniform float blur; // = 0.6
// @color Color the view fades to
uniform vec4 color; // = vec4(0.0, 0.0, 0.0, 1.0)

const int TAPS = 8;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 image(vec2 uv, bool incoming) {
  vec4 c = incoming ? getToColor(mirror(uv)) : getFromColor(mirror(uv));
  return vec4(c.rgb * c.a, c.a);
}

// a small blur disc around uv (premultiplied), golden-angle taps
vec4 soft(vec2 uv, float r, bool incoming) {
  vec4 s = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float k = float(i) + 0.5;
    float a = 2.39996 * k;
    s += image(uv + sqrt(k / float(TAPS)) * vec2(cos(a) / ratio, sin(a)) * r, incoming);
  }
  return s / float(TAPS);
}

vec4 transition(vec2 uv) {
  float p = progress;
  bool incoming = p >= 0.5;
  // how far gone the viewer is: 0 at both ends, 1 at the cut
  float a = incoming ? 2.0 - 2.0 * p : 2.0 * p;
  // the view closes steadily, and clears quickly once it starts to come back
  float g = incoming ? a * sqrt(a) : a;
  // the view closes in steps, two heartbeat throbs: fast, pause, fast
  float closing = g - sin(12.566371 * g) / 12.566371;
  // the two copies drift apart and sway, one up and one down
  float sway = sin(9.0 * p + 1.3);
  vec2 off = separation * smoothstep(0.0, 0.5, a) * vec2(1.0, 0.25 * sway) * vec2(1.0 / ratio, 1.0);
  float r = 0.03 * blur * a;
  // tunnel vision: a dark, wide soft rim closes in from the edges toward the center
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float d = length(q) / (0.5 * length(vec2(ratio, 1.0)));
  // (its soft rim narrows with it, so the middle stays clear until the very end,
  // and a pinpoint of light is left at the darkest moment)
  float R = mix(1.8, 0.05, closing);
  float v = smoothstep(0.6 * R - 0.02, R + 0.001, d);
  if (v >= 1.0) return color;
  vec4 c;
  if (a <= 0.0) c = image(uv, incoming);
  else {
    c = 0.5 * (soft(uv + off, r, incoming) + soft(uv - off, r, incoming));
    // at the darkest moment the two images melt into each other, so the cut never pops
    float w = smoothstep(0.46, 0.54, p);
    if (w > 0.0 && w < 1.0) {
      vec4 other = 0.5 * (soft(uv + off, r, !incoming) + soft(uv - off, r, !incoming));
      c = incoming ? mix(other, c, w) : mix(c, other, w);
    }
  }
  c = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
  // the colors drain and the light goes as the viewer fades
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  c.rgb = mix(c.rgb, vec3(lum), 0.5 * a) * (1.0 - 0.3 * a);
  return mix(c, color, v);
}
