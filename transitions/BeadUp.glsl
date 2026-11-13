// Author: gre
// License: MIT
// Description: The outgoing image is a thin film of liquid on glass that pulls itself apart like water on a waxed surface: dry holes open and grow with glossy rolled rims, meet in a web of ridges, the ridges break into round beads that magnify the picture, and the beads dry up over the incoming image
// Tags: liquid, water, surface-tension, refraction, organic

// @range(2, 6) Number of rows of holes across the frame
uniform float holes; // = 2.5
// @range(0.01, 0.06) Radius of the rims and beads, in frame heights (at most a seventh of the space between holes)
uniform float rim; // = 0.026
// @range(0, 1) Strength of the reflections and of the magnification in the liquid
uniform float gloss; // = 0.7

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec3 hash3(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// the liquid at x (frame heights): x = signed distance into the liquid (negative where dry), y = height
vec2 liquid(vec2 x, float p) {
  float cs = 1.0 / max(holes, 1.0);
  // the rims and beads stay small next to the holes, so the beads keep round when holes are many
  float w = clamp(rim, 0.001, 0.15 * cs);
  vec2 cell = floor(x / cs);
  float d1 = 1e3, d2 = 1e3;
  vec2 c1 = vec2(0.0), c2 = vec2(1.0, 0.0);
  float s1 = 0.0, s2 = 0.0;
  float hRim = 0.0;
  for (int j = -2; j <= 2; j++) {
    for (int i = -2; i <= 2; i++) {
      vec2 n = cell + vec2(float(i), float(j));
      vec3 h = hash3(n + 17.0);
      vec2 c = (n + 0.5 + 0.75 * (h.xy - 0.5)) * cs;
      // each hole opens at its own time and grows at a steady speed
      float age = p - 0.28 * h.z;
      if (age <= 0.0) continue;
      float d = length(x - c) - 2.3 * cs * age - 0.6 * smoothstep(0.6, 1.0, p);
      // the rolled rim in front of the hole, which gathers as the hole opens instead of popping in at full size
      float wh = w * smoothstep(0.0, 0.06, age);
      hRim = max(hRim, sqrt(max(wh * wh - (d - wh) * (d - wh), 0.0)));
      if (d < d1) { d2 = d1; c2 = c1; s2 = s1; d1 = d; c1 = c; s1 = h.x; }
      else if (d < d2) { d2 = d; c2 = c; s2 = h.x; }
    }
  }
  // the rims stand on the film only; between holes that already meet, the ridge takes over
  hRim *= step(0.0, d1);
  if (d2 > 1e2) return vec2(d1, hRim);
  // where two holes meet, their rims merge into a ridge along the line between them
  float e = 0.5 * (d2 - d1);
  float meet = clamp(1.0 - 0.5 * (d1 + d2) / (2.0 * w), 0.0, 1.0);
  vec2 axis = normalize(c2 - c1);
  // the same way for both holes, so the beads line up across the ridge
  axis *= axis.x < 0.0 ? -1.0 : 1.0;
  float along = dot(x - 0.5 * (c1 + c2), vec2(-axis.y, axis.x));
  // the ridge pinches into a row of round beads, which then dry up
  float lambda = 6.5 * w;
  float k = along / lambda + s1 + s2;
  float db = length(vec2(e, (fract(k) - 0.5) * lambda));
  float beading = smoothstep(0.4, 0.62, p);
  float dry = 1.0 - smoothstep(0.62, 0.97, p);
  float wr = w * sqrt(meet) * (1.0 - beading);
  float rb = 1.55 * w * smoothstep(0.0, 1.0, beading) * dry;
  float hRidge = sqrt(max(wr * wr - e * e, 0.0));
  float hBead = sqrt(max(rb * rb - db * db, 0.0));
  float inside = max(d1, max(wr > 0.0 ? wr - e : -1.0, rb > 0.0 ? rb - db : -1.0));
  return vec2(inside, max(hRim, max(hRidge, hBead)));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 x = uv * asp;
  vec2 L = liquid(x, p);
  float px = 0.0015;
  float cover = clamp(L.x / px + 0.5, 0.0, 1.0);
  vec4 to = getToColor(uv);
  // the dry glass: a faint damp halo just outside the liquid
  to.rgb *= 1.0 - 0.18 * gloss * (1.0 - smoothstep(0.8, 0.98, p)) * (1.0 - smoothstep(0.0, 0.012, -L.x)) * step(L.x, 0.0);
  if (cover <= 0.0) return to;

  float eps = 0.002;
  vec2 g = vec2(liquid(x + vec2(eps, 0.0), p).y - L.y, liquid(x + vec2(0.0, eps), p).y - L.y) / eps;
  g = clamp(g, -6.0, 6.0);
  vec3 n = normalize(vec3(-g, 1.0));
  // magnified through the liquid: the picture is pulled toward the top of each bump
  vec2 off = g * L.y * 0.5 * gloss;
  vec4 img = getFromColor(fold((x + off) / asp));
  vec3 light = normalize(vec3(-0.45, 0.55, 0.7));
  vec3 hv = normalize(light + vec3(0.0, 0.0, 1.0));
  float diffuse = dot(n, light) - light.z;
  float spec = max(pow(max(dot(n, hv), 0.0), 60.0) - pow(hv.z, 60.0), 0.0);
  // the steep sides of the liquid look darker, the tops catch the light
  float side = pow(1.0 - n.z, 3.0);
  vec3 c = img.rgb * (1.0 + 0.45 * gloss * diffuse) * (1.0 - 0.5 * gloss * side) + gloss * spec;
  // a thin dark line where the liquid meets the glass
  c *= 1.0 - 0.35 * gloss * (1.0 - smoothstep(0.0, 0.004, L.x));
  vec4 wet = vec4(c, img.a);
  return mix(to, wet, cover);
}
