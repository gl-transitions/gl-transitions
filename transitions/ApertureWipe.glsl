// Author: gre
// License: MIT
// Description: A camera aperture opens its turning blades to reveal the incoming image
// Tags: shape, wipe, iris, rotate

#define PI 3.141592653589793

// @range(3, 12) Number of blades
uniform int blades; // = 6
// @range(-180, 180) How much the blades turn while opening, in degrees
uniform float rotation; // = 60.0
// @range(0, 1) How dark the blades are shaded along their edges
uniform float shadow; // = 0.5

const float AA = 0.006;

vec4 transition (vec2 uv) {
  // Square pixels, normalized so the frame's corners are at distance 1
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0) / (0.5 * length(vec2(ratio, 1.0)));
  float n = clamp(float(blades), 3.0, 12.0);
  float sector = 2.0 * PI / n;
  float turn = radians(rotation) * progress;
  // Each blade's straight edge is at distance r from the center: the opening is the polygon they enclose
  float r = mix(-AA, 1.0 + AA, progress);
  float dist = -1e3;
  float seam = 0.0;
  for (int i = 0; i < 12; i++) {
    if (float(i) < n) {
      float angle = turn + float(i) * sector;
      float d = dot(q, vec2(cos(angle), sin(angle))) - r;
      float next = dot(q, vec2(cos(angle + sector), sin(angle + sector))) - r;
      dist = max(dist, d);
      // Past its corner, the edge of a blade lies over the next blade and casts a shadow on it
      float s = 1.0 - smoothstep(0.0, 0.12, -d);
      seam = max(seam, (1.0 - smoothstep(0.0, AA, d)) * s * s * smoothstep(0.0, AA, next));
    }
  }
  // The blades are also shaded along the opening; the shading fades in as the aperture starts to open
  float rim = 1.0 - smoothstep(0.0, 0.08, dist);
  float shade = shadow * max(rim * rim, seam) * smoothstep(0.0, 0.1, progress);
  vec4 from = getFromColor(uv);
  from.rgb *= 1.0 - shade;
  return mix(from, getToColor(uv), 1.0 - smoothstep(0.0, AA, dist));
}
