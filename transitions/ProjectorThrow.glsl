// Author: gre
// License: MIT
// Description: The lights go down on the outgoing image and a projector throws the incoming one onto it: a small, blurred, keystoned picture of light lands on the scene, tinted by the colors it falls on, then grows, comes into focus and squares up until it fills the frame as the scene beneath it fades away
// Tags: light, projector, projection, keystone, focus, reveal

// @range(0, 1) How dark the outgoing image gets once the lights go down
uniform float darkness; // = 0.8
// @range(0, 0.8) How much wider the top of the projected picture is than its bottom when it lands
uniform float keystone; // = 0.45
// @range(0, 0.05) How out of focus the projected picture is when it lands, in frame heights
uniform float blur; // = 0.015

// folds coordinates back into the frame, so the picture never shows its clamped edges
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the projected picture, sampled with 8 taps on a disc of radius r (in its own coordinates),
// averaged premultiplied so transparent texels do not bleed into it
vec4 projected(vec2 q, vec2 r) {
  vec4 c = vec4(0.0);
  for (int i = 0; i < 8; i++) {
    float a = float(i) * 2.39996;
    vec2 o = sqrt((float(i) + 0.5) / 8.0) * vec2(cos(a), sin(a));
    vec4 t = getToColor(mirror(q + o * r));
    c += vec4(t.rgb * t.a, t.a);
  }
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a / 8.0) : vec4(0.0);
}

vec4 transition(vec2 uv) {
  float p = progress;
  if (p <= 0.0) return getFromColor(uv);
  if (p >= 1.0) return getToColor(uv);
  vec4 from = getFromColor(uv);

  // the lamp warms up as the room lights go down
  float on = smoothstep(0.06, 0.26, p);
  float ambient = 1.0 - darkness * smoothstep(0.0, 0.2, p);
  // the picture grows and squares up, while it comes into focus
  float g = smoothstep(0.02, 1.0, p);
  float focus = 1.0 - smoothstep(0.15, 0.85, p);
  float size = mix(0.32, 1.0, g * (0.6 + 0.4 * g));
  float k = keystone * (1.0 - g);
  float cy = mix(0.58, 0.5, g);

  // keystone: the picture is a trapezoid seen in perspective, its rows spaced wider where it is wider
  float y = (uv.y - cy) / size + 0.5;
  float wy = max(1.0 - 0.5 * k + k * y, 0.05);
  vec2 q = vec2((uv.x - 0.5) / (size * wy) + 0.5, y * (1.0 + 0.5 * k) / wy);

  // soft edges of the beam, in frame heights, sharp once in focus
  float e = min((0.5 * size * wy - abs(uv.x - 0.5)) * ratio, size * min(y, 1.0 - y));
  float soft = 0.0015 + 0.035 * focus;
  float cov = mix(smoothstep(-soft, soft, e), 1.0, smoothstep(0.9, 1.0, p));
  // stray light spilling around the beam
  float halo = 0.15 * focus * on * exp(-24.0 * max(-e, 0.0)) * (1.0 - cov);

  // the light of the picture: brighter while concentrated on a small area, with a lamp vignette
  vec2 d = q - 0.5;
  float gain = on * mix(1.25, 1.0, g) * (1.0 + focus * (0.15 - 1.2 * dot(d, d)));
  // the blur is round on the frame: picture coordinates stretch with the keystone
  vec2 r = blur * focus / (size * wy) * vec2(1.0 / ratio, (1.0 - 0.25 * k * k) / wy);
  vec4 pic = projected(q, r);
  vec3 light = pic.rgb * gain * cov + halo;

  // light lands on the dimmed scene and is tinted by its colors; under the picture, the scene
  // fades to a plain screen
  float screen = smoothstep(0.35, 0.95, p);
  vec3 surface = mix(from.rgb, vec3(1.0), 0.35 + 0.65 * screen);
  vec3 col = from.rgb * ambient * (1.0 - cov * screen) + surface * light;
  // the picture of light shows even over a transparent scene
  return vec4(col, mix(max(from.a, pic.a * cov * on), pic.a, cov * screen));
}
