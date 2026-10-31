// Author: gre
// License: MIT
// Description: The outgoing image parts in the middle like stage curtains, gathering into shaded folds as it is pulled to the sides
// Tags: split, horizontal, fold, 3d

// @range(1, 16, 1) Number of folds in each curtain (fewer in a portrait image)
uniform float folds; // = 7.0
// @range(0, 1) Depth of the shading on the folds
uniform float shading; // = 0.7
// @range(0, 0.4) Width of each curtain once gathered, relative to the image width
uniform float bunch; // = 0.12
// @range(0, 1) How much the bottom of the curtains lags behind the top
uniform float sway; // = 0.4

const float PI = 3.141592653589793;

vec4 transition (vec2 uv) {
  // the bottom of the fabric follows the top with a little delay
  float lag = sway * (1.0 - uv.y);
  float p = progress * (1.0 - lag * (1.0 - progress));
  float open = mix(p, p * p * (3.0 - 2.0 * p), 0.75);
  // each curtain hangs from its outer edge, gathers to the bunch width, then leaves the frame
  float edge = -bunch * open * open;
  float w = mix(0.5, bunch, open);
  float x = min(uv.x, 1.0 - uv.x) - edge; // distance to the outer edge of the curtain
  if (x >= w) {
    // soft shadow of the curtain on the stage, fading as the curtain leaves the frame
    vec4 to = getToColor(uv);
    float shadow = 0.4 * exp((w - x) * 25.0) * clamp((edge + w) * 20.0, 0.0, 1.0);
    return vec4(to.rgb * (1.0 - shadow * open), to.a);
  }
  float t = x / w;
  // pleats: the fabric bunches up where cos(a) > 0 and is stretched elsewhere
  float n = max(1.0, floor(folds * min(ratio, 1.0) + 0.5)); // folds keep their size in portrait
  float a = 2.0 * PI * n * t;
  float f = 1.0 - (1.0 - open) * (1.0 - open) * (1.0 - open); // the folds form early
  float gather = 0.92 * f;
  float s = 0.5 * (t + gather * sin(a) / (2.0 * PI * n)); // position in the fabric
  vec4 c = getFromColor(vec2(uv.x < 0.5 ? s : 1.0 - s, uv.y));
  // light comes from the front, a bit from the middle of the stage
  float slope = 3.0 * gather * cos(a) * (uv.x < 0.5 ? 1.0 : -1.0);
  float diffuse = (1.0 + 0.5 * slope) / sqrt(1.25 * (1.0 + slope * slope));
  float crease = 0.5 + 0.5 * sin(a); // the back of each pleat is in the dark
  float light = mix(1.0, diffuse * (1.0 - 0.6 * crease * crease), shading * f);
  return vec4(c.rgb * light, c.a);
}
