// Author: gre
// License: MIT
// Description: A camera flash freezes the outgoing image into a printed photo with a white border, which shrinks, tilts and drops out of the frame, revealing the incoming image behind it
// Tags: photo, flash, scale, rotate, fall, shadow

// @range(0, 1) How much the photo turns as it drops
uniform float tilt; // = 0.35
// @range(0, 0.15) Width of the photo's border, relative to the frame height
uniform float border; // = 0.04
// @range(0, 1) Strength of the camera flash
uniform float flash; // = 0.85
// @range(0, 1) Darkness of the soft shadow the photo casts on the incoming image
uniform float shadow; // = 0.45
// @color Color of the photo's border
uniform vec4 borderColor; // = vec4(0.96, 0.94, 0.89, 1.0)

const float SHRINK = 0.24; // how much smaller the photo gets before it drops
const float RADIUS = 0.008; // corner radius of the photo, in frame heights
const float AA = 0.0015; // width of the antialiased edges, in frame heights

// signed distance to a rounded box of half size b and corner radius r
float roundedBox(vec2 q, vec2 b, float r) {
  vec2 d = abs(q) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  vec2 halfImage = 0.5 * asp;
  vec2 halfCard = halfImage + border;

  // the photo shrinks right after the flash, then falls with gravity, turning as it goes
  float k = smoothstep(0.05, 0.4, p);
  float t = clamp((p - 0.3) / 0.7, 0.0, 1.0);
  float fall = t * t;
  float s = 1.0 - SHRINK * k;
  float a = -tilt * (0.12 * k + 0.88 * fall);
  // fall far enough for the turned photo and its shadow to be out of the frame at the end
  float bound = (abs(sin(tilt)) * halfCard.x + abs(cos(tilt)) * halfCard.y) * (1.0 - SHRINK);
  // it is lifted a little toward the viewer before it falls
  float lift = 0.035 * k * (1.0 - fall);
  vec2 center = vec2(0.08 * fall, lift - (0.5 + bound + 0.1) * fall);

  float rad = RADIUS * k;

  float ca = cos(a), sa = sin(a);
  mat2 unrotate = mat2(ca, -sa, sa, ca);

  // the incoming image, already behind the photo, in its soft shadow
  vec4 col = getToColor(uv);
  float sh = shadow * k;
  if (sh > 0.0) {
    vec2 rs = unrotate * (q - center - vec2(0.012, -0.022) * k) / s;
    float ds = roundedBox(rs, halfCard, rad) * s;
    float blur = 0.035 * s;
    col.rgb *= 1.0 - sh * (1.0 - smoothstep(-blur, blur, ds));
  }
  col = premultiply(col);

  // the photo: the outgoing image, framed by its border
  vec2 r = unrotate * (q - center) / s;
  float dCard = roundedBox(r, halfCard, rad) * s;
  float dImage = roundedBox(r, halfImage, 0.0) * s;
  // the edges are pushed out by one antialiasing width, so the photo covers the full frame at the start
  float cardCover = clamp(1.5 - dCard / AA, 0.0, 1.0);
  float imageCover = clamp(1.5 - dImage / AA, 0.0, 1.0);
  // the image replaces what is behind it, while the border is laid over the incoming image, which shows through a translucent border
  vec4 photo = premultiply(getFromColor(clamp(r / asp + 0.5, 0.0, 1.0)));
  vec4 paper = premultiply(borderColor);
  vec4 card = mix(paper + col * (1.0 - paper.a), photo, imageCover);
  col = mix(col, card, cardCover);
  if (col.a <= 0.0) return vec4(0.0);
  col.rgb /= col.a;

  // the flash only adds light: a quick bloom to white that fades as the photo comes out
  float f = flash * smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.05, 0.3, p));
  col.rgb = 1.0 - (1.0 - col.rgb) * (1.0 - f);
  return col;
}
