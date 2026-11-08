// Author: gre
// License: MIT
// Description: A black disk appears and grows, bending the outgoing image around it like a heavy mass bends light: the image is stretched into a bright ring at the disk's edge and swallowed until the frame is black, then the disk shrinks back, unbending the incoming image
// Tags: distort, lens, space, circular, dark

// Center of the disk
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 1.5) How strongly the light bends: radius of the lensed ring beyond the disk's edge, in disk radii
uniform float strength; // = 0.6
// @range(0, 1) Brightness of the lensed ring and of the thin ring of light hugging the disk's edge
uniform float glow; // = 0.6
// @color Color of the disk
uniform vec4 hole; // = vec4(0.0, 0.0, 0.0, 1.0)

// how far past the farthest corner the disk grows, so the frame is fully covered for a brief moment
const float OVERSHOOT = 0.12;
// moment the frame is black: the swallow takes a little longer than the release
const float PEAK = 0.55;
// half width of the antialiased edge of the disk, in frame heights
const float AA = 0.002;
// tint of the light piled up around the disk
const vec3 WARM = vec3(1.0, 0.86, 0.68);

// fold the coordinates back into the frame, so the image stays filled without smearing its border
vec2 mirrored(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

vec4 transition(vec2 uv) {
  // the disk grows with an accelerating swallow, then shrinks back a little faster: exactly 0 at both ends
  bool swallowing = progress < PEAK;
  float u = swallowing ? progress / PEAK : (1.0 - progress) / (1.0 - PEAK);
  float u2 = u * u;
  float k = u2 * (0.6 + 0.4 * u2);

  // measured in frame heights, so the disk is round
  vec2 aspect = vec2(ratio, 1.0);
  vec2 far = max(center, 1.0 - center) * aspect;
  float rh = length(far) * (1.0 + OVERSHOOT) * k;
  // radius where the light coming from right behind the disk shows up as a ring
  float re = rh * (1.0 + max(strength, 0.0));

  vec2 d = (uv - center) * aspect;
  float r = max(length(d), 1e-5);
  // a point mass deflects the light by an angle falling off as 1/r
  vec2 q = mirrored(center + d * (1.0 - re * re / (r * r)) / aspect);
  vec4 c = swallowing ? getFromColor(q) : getToColor(q);
  // the shading fades in with the disk, so it is exactly 0 at both ends
  float amount = smoothstep(0.0, 0.04, rh);
  // the second, flipped image squeezed between the ring and the disk is dimmer
  float inner = clamp((r - rh) / (re - rh + 1e-4), 0.0, 1.0);
  c.rgb *= 1.0 - 0.7 * amount * (1.0 - inner * inner * (3.0 - 2.0 * inner));

  // light piles up into a ring where the image is most stretched, and into a thin ring hugging the edge
  float g = max(glow, 0.0) * amount;
  float einstein = (r - re) / (0.3 * (re - rh) + 0.01);
  float photon = max(r - rh, 0.0) / (0.006 + 0.012 * rh);
  float light = g * (0.7 * exp(-einstein * einstein) + 1.6 * exp(-photon * photon));
  c.rgb = min(c.rgb * (1.0 + light) + WARM * (0.35 * light * c.a), vec3(1.0));

  // antialiased horizon, kept inside the disk so it vanishes with it
  float cov = clamp((rh - r) / (2.0 * AA), 0.0, 1.0);
  return mix(c, hole, cov);
}
