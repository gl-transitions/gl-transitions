// Author: gre
// License: MIT
// Description: A round glass lens grows from a point over the outgoing image, casting a soft shadow on it, and shows the incoming image magnified through it, with a bright bevelled rim and faint color fringes; as the lens fills the frame the magnification relaxes until the incoming image lies flat
// Tags: lens, glass, circle, iris, magnify, reveal

// @param Point the lens grows from
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 0.8) How strongly the lens magnifies the middle of the incoming image at the start
uniform float strength; // = 0.5
// @range(0, 1) Strength of the rim's light and shade and of the shadow the lens casts (0 for a clean cut)
uniform float shading; // = 0.6

// half width of the antialiased edge of the lens, in frame heights
const float AA = 0.0015;
// width of the bevelled rim, in lens radii
const float BEVEL = 0.07;
// moment the lens has grown past the farthest corner
const float OPEN = 0.8;
// toward the light, from the top left (xy of a unit vector)
const vec2 LIGHT = vec2(-0.6, 0.8);

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float p = progress;
  vec2 aspect = vec2(ratio, 1.0);
  float sh = clamp(shading, 0.0, 1.0);

  // the lens grows from a gentle start and lands softly once its bevel is past the farthest corner
  vec2 far = max(center, 1.0 - center) * aspect;
  float full = length(far) / (1.0 - BEVEL) + 2.0 * AA;
  float t = clamp(p / OPEN, 0.0, 1.0);
  float radius = full * t * (0.5 + t * (2.0 - 1.5 * t));

  // the magnification relaxes while the lens finishes growing: exactly 0 at the end
  float k = clamp(strength, 0.0, 0.8) * (1.0 - smoothstep(0.35, 1.0, p));

  vec2 d = (uv - center) * aspect;
  float r = length(d);

  // outside: the outgoing image, under the soft shadow of the lens hovering above it, away from the light
  vec4 a = vec4(0.0);
  if (r > radius - 2.0 * AA) {
    a = getFromColor(uv);
    float sd = length(d + 0.1 * LIGHT * radius) / max(radius, 1e-5);
    float shadow = 0.55 * sh * (1.0 - smoothstep(0.85, 1.35, sd)) * smoothstep(0.0, 0.05, radius);
    a.rgb *= 1.0 - shadow;
    if (r >= radius) return a;
  }

  // inside: the incoming image through a magnifying lens, the middle enlarged and the rim squeezed;
  // the colors are bent a little differently, more toward the rim
  float s = r / radius;
  float f = 1.0 - k * (1.0 - s * s);
  vec2 n = r > 0.0 ? d / r : vec2(0.0);
  vec2 ca = n * (0.014 * k * s * s) / aspect;
  vec2 q = center + d * f / aspect;
  // each channel keeps the alpha of the tap it comes from
  vec4 cr = getToColor(mirror(q + ca));
  vec4 cg = getToColor(mirror(q));
  vec4 cb = getToColor(mirror(q - ca));
  float alpha = (cr.a + cg.a + cb.a) / 3.0;
  vec4 b = vec4(vec3(cr.r * cr.a, cg.g * cg.a, cb.b * cb.a) / max(alpha, 1e-5), alpha);

  // the bevelled rim: its slope faces the light on the top left side and turns away on the other
  float bevel = smoothstep(1.0 - BEVEL, 1.0, s);
  float facing = dot(n, LIGHT);
  float lit = bevel * bevel;
  vec3 shade = vec3(1.0 - 0.35 * sh * lit * max(-facing, 0.0) - 0.12 * sh * bevel);
  float spec = sh * lit * (0.55 * max(facing, 0.0) + 0.12);
  // a soft glint on the glass, on the light's side of the middle
  vec2 g = (d / radius - 0.42 * LIGHT) / vec2(0.32, 0.2);
  float glint = 0.12 * sh * exp(-dot(g, g)) * (1.0 - smoothstep(0.6, 1.0, p));
  b.rgb = min(b.rgb * shade + (spec + glint) * b.a, vec3(1.0));

  // antialiased edge, kept inside the lens so it vanishes with it
  float cov = clamp((radius - r) / (2.0 * AA), 0.0, 1.0);
  return mix(a, b, cov);
}
