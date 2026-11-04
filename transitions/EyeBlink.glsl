// Author: gre
// License: MIT
// Description: Curved eyelids close from the top and bottom over the outgoing image, which blurs and dims, then open on the incoming image as it comes back into focus, as if the viewer blinked
// Tags: blink, eye, blur, shape

// @range(0, 1) How much the image blurs and dims while the eyes are closed
uniform float blur; // = 0.5
// @range(0.01, 0.3) Width of the soft shadow along the rim of the eyelids
uniform float softness; // = 0.12
// @range(1, 2, 1) Number of blinks: 1, or 2 for a quick double blink (the cut happens on the first one)
uniform int blinks; // = 1
// @color Color of the eyelids
uniform vec4 color; // = vec4(0.03, 0.02, 0.02, 1.0)

const int TAPS = 16;
// how much the eyelids curve: the opening is widest at the center and the corners close first
const float CURVE = 0.25;
// where the eyelids meet, below the middle: the upper lid travels further than the lower one
const float MEET = 0.44;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// a blink fully closed at c (held for 2 * hold): the lids close over wc before it
// and open over wo after it, slower, like a real blink
float lidBlink(float t, float c, float wc, float wo, float hold) {
  return 1.0 - smoothstep(hold, t < c ? wc : wo, abs(t - c));
}

vec4 image(vec2 uv, bool incoming) {
  vec4 c = incoming ? getToColor(uv) : getFromColor(uv);
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  bool two = blinks > 1;
  // the moment the eyes are fully closed, when the images are swapped
  float cut = two ? 0.3 : 0.42;
  // how closed the eyes are: 0 open, 1 closed
  float closed = two
    ? max(lidBlink(progress, cut, 0.26, 0.26, 0.015), lidBlink(progress, 0.7, 0.14, 0.24, 0.01))
    : lidBlink(progress, cut, 0.36, 0.5, 0.02);
  bool incoming = progress >= cut;

  // the rim of each eyelid is an arc; fully open, even its corners clear the frame by the widest shadow
  float soft = clamp(softness, 0.001, 0.3);
  float x = 2.0 * uv.x - 1.0;
  float rim = (1.0 - closed) * (1.31 + CURVE) - CURVE * x * x;
  // distance inside the opening from the nearest lid, as a share of that lid's travel
  float y = uv.y - MEET;
  float d = rim - max(y / (1.0 - MEET), -y / MEET);
  // the lid fills beyond its rim, with a soft shadow falling inside the opening
  float s = 1.0 - smoothstep(0.0, soft, d);
  float lid = s * s;
  if (lid >= 1.0) return color;

  // how out of focus and dim the view is: it peaks at the cut, follows the lids, and clears at both ends
  float f = progress < cut ? progress / cut : (1.0 - progress) / (1.0 - cut);
  f = clamp(f, 0.0, 1.0);
  f = max(f * (2.0 - f), closed) * blur;

  vec4 c;
  if (f <= 0.0) {
    c = incoming ? getToColor(uv) : getFromColor(uv);
  } else {
    // a disc of taps along a golden-angle spiral, premultiplied
    float r = 0.025 * f;
    c = vec4(0.0);
    for (int i = 0; i < TAPS; i++) {
      float k = float(i) + 0.5;
      float a = 2.39996 * k;
      vec2 o = sqrt(k / float(TAPS)) * vec2(cos(a), sin(a)) * r;
      c += image(mirror(uv + o * vec2(1.0 / ratio, 1.0)), incoming);
    }
    c /= float(TAPS);
    c = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
    // less light reaches the eye as it closes
    c.rgb *= 1.0 - 0.35 * f;
  }
  return mix(c, color, lid);
}
