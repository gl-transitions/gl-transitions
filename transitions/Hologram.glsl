// Author: gre
// License: MIT
// Description: The outgoing image turns into a flickering hologram (blue by default) with scanlines and jittering rows, breaks up, and the hologram resolves into the incoming image in full color
// Tags: hologram, sci-fi, scanlines, flicker, glitch

// @color Color of the hologram
uniform vec3 tint; // = vec3(0.2, 0.75, 1.0)
// @color Color behind the hologram, seen between its scanlines and where it breaks up
uniform vec4 background; // = vec4(0.0, 0.02, 0.05, 1.0)
// @range(20, 300) Number of scanlines over the frame height
uniform float scanlines; // = 150.0
// @range(0, 0.2) How far rows of the hologram jump sideways, relative to the frame width
uniform float jitter; // = 0.04
// @range(0, 1) Strength of the flicker and of the rows that drop out
uniform float flicker; // = 0.6

const float PI = 3.14159265;
// steps per transition of the flicker and the jitter
const float STEPS = 32.0;

float hash(vec2 p) {
  p = fract(p * vec2(443.897, 441.423));
  p += dot(p, p.yx + 19.19);
  return fract((p.x + p.y) * p.x);
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// the image the hologram shows: rows switch from the outgoing image to the incoming one
// while the hologram breaks up
vec4 source(vec2 uv, float m) {
  return m > 0.5 ? getToColor(uv) : getFromColor(uv);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  float p = progress;
  // how much of the hologram shows, and how broken up it is (peaking mid-transition)
  float h = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.7, 1.0, p));
  float b = smoothstep(0.0, 1.0, 1.0 - abs(p - 0.5) / 0.22);
  float f = floor(p * STEPS);

  // rows of the hologram jump sideways, more while it breaks up
  float band = floor(uv.y * 36.0);
  float jump = step(1.0 - (0.2 + 0.6 * b) * h, hash(vec2(band, f)));
  float offset = (hash(vec2(band, f + 0.37)) - 0.5) * 2.0 * jitter * jump * (0.3 + 0.7 * b);
  offset += sin(uv.y * 23.0 + f * 1.7) * 0.0015 * h;
  vec2 q = uv + vec2(offset, 0.0);

  // when each row of the hologram switches to the incoming image
  float m = step(hash(vec2(floor(uv.y * 24.0), 7.0)), (p - 0.35) / 0.3);

  // the hologram: the luma of the image in the tint, with colored fringes
  // (sampled inside the frame, the fringes weighted by the alpha of their texels)
  vec4 c = source(clamp(q, 0.0, 1.0), m);
  vec2 dx = vec2(0.003 + 0.01 * b, 0.0);
  float l = luma(c.rgb);
  vec4 cr = source(clamp(q + dx, 0.0, 1.0), m);
  vec4 cb = source(clamp(q - dx, 0.0, 1.0), m);
  float lr = luma(cr.rgb) * cr.a;
  float lb = luma(cb.rgb) * cb.a;
  vec3 g = smoothstep(0.05, 0.9, vec3(lr, l, lb));
  // the brightest parts burn toward white
  vec3 holo = tint * (0.06 + 1.25 * g) + 0.45 * g * g * g;
  // brighter scan band rolling down
  float roll = fract(uv.y + 2.0 * p);
  holo += tint * 0.35 * smoothstep(0.85, 1.0, roll) * (1.0 - smoothstep(0.98, 1.0, roll));
  holo = clamp(holo, 0.0, 1.0);
  // nothing outside the image where a row jumped out of the frame
  float inside = step(0.0, q.x) * step(q.x, 1.0);

  // opacity of the hologram: scanlines, flicker and missing rows
  float lines = 0.5 + 0.5 * sin((uv.y * scanlines - p * 6.0) * 2.0 * PI);
  float vis = mix(1.0, 0.15 + 0.85 * lines, h);
  vis *= 1.0 - flicker * (0.25 + 0.75 * b) * hash(vec2(f, 3.1)) * h;
  float gap = step(hash(vec2(floor(uv.y * 90.0), f + 0.71)), flicker * 0.45 * b);
  vis *= 1.0 - gap;
  vec4 layer = vec4(holo, c.a * vis * inside);
  // the hologram over its background, transparent where neither the image nor the
  // hologram is
  vec4 plain = premultiplied(source(uv, m));
  vec4 back = premultiplied(vec4(background.rgb, background.a * max(plain.a, layer.a)));
  vec4 holoColor = premultiplied(layer) + back * (1.0 - layer.a);

  // the images in full color, then the hologram over them
  vec4 o = mix(plain, holoColor, h);
  return o.a > 0.0 ? vec4(o.rgb / o.a, o.a) : vec4(0.0);
}
