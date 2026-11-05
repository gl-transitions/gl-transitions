// Author: gre
// License: MIT
// Description: A dissolve where, at each point, only the brighter of the two images shows: the incoming image rises from black and breaks through wherever it outshines the outgoing one, highlights first, then the outgoing image sinks away, shadows first
// Tags: dissolve, blend, light, luma

// @range(0, 0.5) Width of the blend between the two images where they are about as bright: 0 is a hard edge
uniform float softness; // = 0.15
// @param Compare each color channel on its own, which mixes the colors of the two images, instead of their brightness
uniform bool perChannel; // = false

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
// brightness under which the two images blend instead of competing
const float DARK = 0.02;

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress <= 0.0) return a;
  if (progress >= 1.0) return b;

  // the incoming image rises from black (or from transparent) over the first half, the outgoing
  // one sinks to black over the second half, so that at the middle both are at full brightness;
  // eased out of black so that the incoming highlights break through early
  float xa = clamp(2.0 - 2.0 * progress, 0.0, 1.0);
  float xb = clamp(2.0 * progress, 0.0, 1.0);
  float wa = xa * (2.0 - xa);
  float wb = xb * (2.0 - xb);
  // premultiplied
  vec3 ca = a.rgb * a.a * wa;
  vec3 cb = b.rgb * b.a * wb;

  vec3 la = perChannel ? ca : vec3(dot(ca, LUMA));
  vec3 lb = perChannel ? cb : vec3(dot(cb, LUMA));
  // relative difference of brightness, from -1 (only the outgoing image) to 1 (only the incoming
  // one); the floor keeps near-black areas, where it would flip on grain, blended
  vec3 d = (lb - la) / max(la + lb, vec3(DARK));
  vec3 m = clamp(0.5 + d / (2.0 * max(softness, 1e-3)), 0.0, 1.0);

  vec3 color = mix(ca, cb, m);
  // the union of the two coverages
  float alpha = max(a.a * wa, b.a * wb);
  return alpha > 0.0 ? vec4(color / alpha, alpha) : vec4(0.0);
}
