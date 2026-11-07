// Author: gre
// License: MIT
// Description: The outgoing image narrows into a curved funnel toward a point on the bottom edge and slides into it, its sides bending like a window minimized into a dock, revealing the incoming image behind it
// Tags: distort, slide, vertical, shadow

// @range(0, 1) Point of the bottom edge where the image disappears, from left (0) to right (1)
uniform float target; // = 0.7
// @range(0, 1) Shape of the funnel's sides: 0 straight, 1 bent into an S curve
uniform float curvature; // = 0.8
// @range(0, 1) Strength of the shading of the bent image and of the shadow it casts
uniform float shadow; // = 0.5

// width of the funnel's neck, as a part of the frame's height
const float NECK = 0.04;
// how far below the bottom edge the image's top ends, so it is gone at the end
const float OVERSHOOT = 0.03;
// width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0015;
// reach of the soft shadow, as a part of the frame's height
const float SOFT = 0.06;

vec4 transition(vec2 uv) {
  float t = progress;
  // one eased timing: the funnel forms from the very start while the slide accelerates into it
  float f = smoothstep(0.0, 1.0, 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t));
  float slide = (1.0 + OVERSHOOT) * t * t * (1.5 - 0.5 * t);

  float r = max(ratio, 1e-4);
  float nh = 0.5 * NECK / r;
  // the whole neck stays in the frame
  float tx = clamp(target, nh, 1.0 - nh);
  float c = clamp(curvature, 0.0, 1.0);

  // the funnel's profile, 0 at the neck on the bottom edge to 1 at the top of the frame
  float q = clamp(uv.y, 0.0, 1.0);
  float w = mix(q, q * q * (3.0 - 2.0 * q), c);
  float dw = mix(1.0, 6.0 * q * (1.0 - q), c);
  float L = f * mix(tx - nh, 0.0, w);
  float R = 1.0 - f * (1.0 - mix(tx + nh, 1.0, w));
  float dL = -f * (tx - nh) * dw;
  float dR = f * (1.0 - tx - nh) * dw;
  float v = uv.y + slide;

  // anti-aliased coverage, measured across the slanted sides (a side on the frame's border is not an edge)
  float e = EDGE * min(1.0, 10.0 * t) + 1e-6;
  float left = L > 0.0 ? (uv.x - L) * r / sqrt(1.0 + dL * dL * r * r) : 1.0;
  float right = R < 1.0 ? (R - uv.x) * r / sqrt(1.0 + dR * dR * r * r) : 1.0;
  float cov = clamp(min(min(left, right), 1.0 - v) / e + 0.5, 0.0, 1.0);

  vec4 img = vec4(0.0);
  float s = clamp(shadow, 0.0, 1.0);
  if (cov > 0.0) {
    float width = R - L;
    vec2 src = clamp(vec2((uv.x - L) / width, v), 0.0, 1.0);
    img = getFromColor(src);
    // the squeezed rows round like a bent sheet, darker on their sides and toward the neck
    float across = 2.0 * src.x - 1.0;
    img.rgb *= 1.0 - s * (1.0 - width) * (0.5 * across * across + 0.3 * (1.0 - w));
    if (cov >= 1.0) return img;
  }

  vec4 bg = getToColor(uv);
  // soft shadow of the funnel cast on the incoming image
  float ox = max(L - uv.x, uv.x - R) * r;
  float oy = uv.y - (1.0 - slide);
  float dist = length(max(vec2(ox, oy), 0.0));
  bg.rgb *= 1.0 - s * 0.6 * f * (1.0 - t) * (1.0 - smoothstep(0.0, SOFT, dist));

  return mix(bg, img, cov);
}
