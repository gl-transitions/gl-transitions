// Author: gre
// License: MIT
// Description: The outgoing image rises like a theater festoon curtain: cords lift its hem into scalloped swags while the fabric gathers into shaded ruffles, and it is drawn up out of the frame over the incoming image
// Tags: 3d, fold, vertical

// @range(1, 8, 1) Number of swags across a 16:9 frame (fewer in a portrait image)
uniform float swags; // = 3.0
// @range(0, 0.3) How low each swag droops between two cords, as a part of the frame's height
uniform float sag; // = 0.14
// @range(4, 30, 1) Number of gathered ruffles in the fabric
uniform float ruffles; // = 14.0
// @range(0, 1) Depth of the shading on the ruffles and swags, and of the shadow under the hem
uniform float shading; // = 0.7

const float PI = 3.141592653589793;

vec4 transition (vec2 uv) {
  float p = progress;
  // the fabric gathers early, then the cords pull it up
  float f = 1.0 - (1.0 - p) * (1.0 - p) * (1.0 - p);
  // the cords start pulling at once and are fastest midway
  float e = mix(p, p * p * (3.0 - 2.0 * p), 0.4);
  float s = sag * f;
  float lift = mix(-0.01, 1.0 + sag + 0.08, e);
  // across a swag, -1 and 1 at the cords
  float n = max(1.0, floor(swags * sqrt(ratio / 1.78) + 0.5)); // fewer swags in portrait
  float u = fract(uv.x * n) * 2.0 - 1.0;
  float bump = 1.0 - u * u;
  float hem = lift - s * bump;
  float aa = 0.002 + 0.004 * f;
  float inside = smoothstep(hem - aa, hem + aa, uv.y);

  vec4 c = vec4(0.0);
  if (inside > 0.0) {
    // q goes from 0 at the top rod to 1 at the hem; the whole height of fabric is gathered into it
    float h = max(1.0 - max(hem, 0.0), 1e-4);
    float q = clamp((1.0 - uv.y) / h, 0.0, 1.0);
    // ruffles: the fabric bunches where cos(a) > 0, rows parallel to the scalloped hem
    // as the curtain shortens, its ruffles merge so none gets thinner than 2% of the frame
    float m = min(max(1.0, floor(ruffles + 0.5)), h / 0.02);
    float a = 2.0 * PI * m * q;
    // the ruffles puff out most in the middle of each swag
    float g = 0.85 * f * min(1.0, 0.3 + 5.0 * (1.0 - h)) * (0.6 + 0.4 * bump);
    float v = clamp(q + g * sin(a) / (2.0 * PI * m), 0.0, 1.0);
    // the fabric is also pulled in toward the cords near the hem
    float pull = 0.25 * f * q * q * sin(PI * u) / (PI * n);
    c = getFromColor(vec2(uv.x - pull, 1.0 - v));

    // light from the front and a bit above
    float slope = 2.5 * g * cos(a);
    float diffuse = (1.0 - 0.35 * slope) / sqrt(1.0 + slope * slope);
    float crease = 0.5 + 0.5 * sin(a);
    float light = mix(1.0, diffuse * (1.0 - 0.45 * crease * crease), shading * g);
    // a soft sheen on the crest of each ruffle
    light += 0.18 * shading * g * smoothstep(0.4, 1.0, -cos(a));
    // each swag bulges toward the light in its middle and is pinched dark along the cords
    float depth = f * q * (0.3 + 0.7 * q);
    light *= 1.0 - shading * depth * (0.35 * u * u + 0.5 * exp(-(1.0 - abs(u)) * 14.0));
    // the hem rolls under a little
    light *= 1.0 - 0.35 * shading * f * exp(-(uv.y - hem) * 120.0);
    c.rgb *= light;
    if (inside >= 1.0) return c;
  }
  vec4 to = getToColor(uv);
  // soft shadow of the curtain just under its hem
  float below = max(hem - uv.y, 0.0);
  float shadow = 0.6 * shading * exp(-below * 22.0) * smoothstep(0.0, 0.05, lift) * (1.0 - smoothstep(1.0, 1.06, lift - s));
  to.rgb *= 1.0 - shadow;
  return mix(to, c, inside);
}
