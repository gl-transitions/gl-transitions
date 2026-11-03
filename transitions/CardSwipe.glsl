// Author: gre
// License: MIT
// Description: The outgoing image is flicked off like the top card of a stack, swinging around a point below it as it flies out, while the incoming card behind it grows to fill the frame
// Tags: card, swipe, stack, rotate, slide, directional

// @param Direction in which the outgoing card is flicked
uniform vec2 direction; // = vec2(1.0, 0.25)
// @range(0, 1) How much the outgoing card swings as it flies out
uniform float rotation; // = 0.5
// @range(0, 0.5) How much smaller the incoming card starts
uniform float depth; // = 0.15
// @color Color seen around the incoming card while it is smaller than the frame
uniform vec4 backColor; // = vec4(0.06, 0.06, 0.07, 1.0)

const float RADIUS = 0.045; // corner radius of the cards, in frame heights
const float AA = 0.002; // width of the antialiased card edges

// signed distance to a rounded box of half size b and corner radius r
float roundedBox(vec2 q, vec2 b, float r) {
  vec2 d = abs(q) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float dl = length(direction);
  vec2 d = dl > 1e-6 ? direction / dl : vec2(0.970143, 0.242536);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  vec2 b = vec2(0.5 * ratio, 0.5);
  float p = progress;

  // the incoming card, behind: grows from a smaller card to the full frame,
  // and its corners straighten as it fills it
  float h = clamp((p - 0.2) / 0.8, 0.0, 1.0);
  float g = h * h * (3.0 - 2.0 * h);
  float k = 1.0 - g;
  float sc = 1.0 - depth * k;
  float rb = RADIUS * min(1.0, 12.0 * k);
  float db = roundedBox(q, b * sc, rb);
  float cb = clamp(0.5 - db / max(AA * min(1.0, 40.0 * k), 1e-6), 0.0, 1.0);
  vec4 tc = getToColor(clamp(0.5 + (uv - 0.5) / sc, 0.0, 1.0));
  // still in the shade of the top card at first
  tc.rgb *= 1.0 - 0.35 * k * k;
  // the cards are opaque: each one replaces what is behind it, keeping its image's alpha
  vec4 col = mix(premultiply(backColor), premultiply(tc), cb);

  // the outgoing card, on top: swings around a point below it as it is flicked away
  float t = clamp(p / 0.75, 0.0, 1.0);
  float lift = smoothstep(0.0, 0.15, p);
  float u = min(t / 0.7, 1.0);
  float swing = u * u * (3.0 - 2.0 * u);
  // it tilts toward the side it is flicked to
  float a = (d.x < 0.0 ? 1.3 : -1.3) * rotation * swing;
  vec2 pivot = vec2(0.0, -1.1);
  // where the swing alone takes the center of the card, to throw it far enough
  float ca = cos(a), sa = sin(a);
  vec2 swung = pivot + mat2(ca, sa, -sa, ca) * -pivot;
  float far = 2.0 * length(b) + length(swung) + 0.3;
  vec2 shift = d * far * t * t * (0.4 + 0.6 * t);
  mat2 unrotate = mat2(ca, -sa, sa, ca);
  vec2 r = unrotate * (q - shift - pivot) + pivot;
  float rf = RADIUS * lift;

  // its soft shadow on the card behind, cast down and away as it lifts
  float sh = 0.6 * lift * (1.0 - t);
  if (sh > 0.0) {
    vec2 rs = unrotate * (q - (0.03 * d + vec2(0.0, -0.03)) * lift - shift - pivot) + pivot;
    float ds = roundedBox(rs, b, rf);
    col.rgb *= 1.0 - sh * (1.0 - smoothstep(-0.05, 0.08, ds));
  }

  float df = roundedBox(r, b, rf);
  float cf = clamp(0.5 - df / max(AA * min(1.0, 40.0 * lift), 1e-6), 0.0, 1.0);
  vec4 fc = getFromColor(clamp(r / vec2(ratio, 1.0) + 0.5, 0.0, 1.0));
  col = mix(col, premultiply(fc), cf);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
