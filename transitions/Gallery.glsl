// Author: gre
// License: MIT
// Description: The camera pulls back from the outgoing image to show it as a slide hanging in a row on a wall in perspective, the row glides along as each slide turns away from the center, and the camera moves back in on the incoming slide until it fills the frame
// Tags: 3d, perspective, gallery, slide, reflection, directional

// @param Way the row moves: 1 brings the incoming slide in from the right, -1 from the left
uniform float direction; // = 1.0
// @range(0, 1) How much the slides turn as they leave the center
uniform float tilt; // = 0.6
// @range(0, 1) Space between two slides, in slide widths
uniform float gap; // = 0.15
// @range(0.2, 3) How far the camera pulls back
uniform float zoom; // = 2.0
// @range(0, 1) Strength of the reflection of the slides on the floor
uniform float reflection; // = 0.3
// @color Color of the wall and the floor around the slides
uniform vec4 background; // = vec4(0.07, 0.07, 0.08, 1.0)

const float FOCAL = 1.6; // distance from the camera to a slide when it fills the frame
const float MAX_ANGLE = 1.4; // turn of a side slide at tilt = 1, in radians
const float NEIGHBOUR = 0.3; // how visible the repeats beyond the two images are
const float AA = 0.002; // width of the antialiased slide edges, in frame heights

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// how far slide k sits from the center of the view, in slides, clamped to one slide on each side
float offset(float k, float camQ, float spacing) {
  return clamp((k * spacing - camQ) / spacing, -1.0, 1.0);
}

// the ray o + t d against slide k of the row (a plane turned around its vertical axis):
// returns (u, v, t, coverage), coverage antialiased over aa frame heights at the slide's edges
vec4 slideHit(vec3 o, vec3 d, float k, float s, float camQ, float spacing, float aa) {
  // a side slide turns away from the center: its outer edge goes back into the wall
  float a = -s * MAX_ANGLE * tilt * offset(k, camQ, spacing);
  vec3 c = vec3(s * k * spacing, 0.0, 0.0);
  vec3 tg = vec3(cos(a), 0.0, sin(a)); // along the slide, left to right
  vec3 n = vec3(-tg.z, 0.0, tg.x);
  float dn = dot(d, n);
  if (abs(dn) < 1e-5) return vec4(0.0, 0.0, -1.0, 0.0);
  float t = dot(c - o, n) / dn;
  vec3 q = o + d * t - c;
  float lx = dot(q, tg) + 0.5 * ratio;
  float ly = q.y + 0.5;
  // distances to the edges on screen: along the slide, how fast its local x moves with the screen x
  float jx = abs(t * (tg.x - dot(d, tg) * n.x / dn));
  float ex = min(lx, ratio - lx) / max(jx, 1e-6);
  float ey = min(ly, 1.0 - ly) / max(t, 1e-6);
  float cov = t > 0.0 ? clamp(0.5 + min(ex, ey) / aa, 0.0, 1.0) : 0.0;
  return vec4(lx / ratio, ly, t, cov);
}

// the premultiplied color of slide k where the ray hit it; the row is from (k = 0), to (k = 1),
// and faint repeats beyond them on their own side; refl > 0 is the strength of its reflection
vec4 slideColor(vec4 h, float k, float camQ, float spacing, float refl, vec4 bg) {
  if (h.w <= 0.0) return vec4(0.0);
  vec2 st = clamp(h.xy, 0.0, 1.0);
  vec4 c = premultiply(k < 0.5 ? getFromColor(st) : getToColor(st));
  // turned away from the light as it turns away from the center
  c.rgb *= 1.0 - 0.3 * tilt * abs(offset(k, camQ, spacing));
  if (k < -0.5 || k > 1.5) c = mix(bg, c, NEIGHBOUR);
  // the reflection fades out below the bottom of the slide
  float f = refl > 0.0 ? refl * (1.0 - smoothstep(0.0, 0.6, st.y)) : 1.0;
  return c * (h.w * f);
}

// how much the slides cover along the ray, whatever their images' alpha
float sceneCover(vec3 o, vec3 d, float s, float camQ, float spacing, float aa) {
  float kc = floor(s * (o.x + d.x * o.z / -d.z) / spacing + 0.5);
  float w0 = slideHit(o, d, kc - 1.0, s, camQ, spacing, aa).w;
  float w1 = slideHit(o, d, kc, s, camQ, spacing, aa).w;
  float w2 = slideHit(o, d, kc + 1.0, s, camQ, spacing, aa).w;
  return 1.0 - (1.0 - w0) * (1.0 - w1) * (1.0 - w2);
}

// the slides seen along the ray, composited back to front (premultiplied)
vec4 scene(vec3 o, vec3 d, float s, float camQ, float spacing, float aa, float refl, vec4 bg) {
  // the slide in front of which the ray crosses the wall, and its two neighbours
  float wallQ = s * (o.x + d.x * o.z / -d.z);
  float kc = floor(wallQ / spacing + 0.5);
  vec4 h0 = slideHit(o, d, kc - 1.0, s, camQ, spacing, aa);
  vec4 h1 = slideHit(o, d, kc, s, camQ, spacing, aa);
  vec4 h2 = slideHit(o, d, kc + 1.0, s, camQ, spacing, aa);
  vec4 c0 = slideColor(h0, kc - 1.0, camQ, spacing, refl, bg);
  vec4 c1 = slideColor(h1, kc, camQ, spacing, refl, bg);
  vec4 c2 = slideColor(h2, kc + 1.0, camQ, spacing, refl, bg);
  float t0 = h0.w > 0.0 ? h0.z : 1e6;
  float t1 = h1.w > 0.0 ? h1.z : 1e6;
  float t2 = h2.w > 0.0 ? h2.z : 1e6;
  // sort far to near: t0 >= t1 >= t2
  vec4 tc;
  float tt;
  if (t0 < t1) { tc = c0; c0 = c1; c1 = tc; tt = t0; t0 = t1; t1 = tt; }
  if (t1 < t2) { tc = c1; c1 = c2; c2 = tc; tt = t1; t1 = t2; t2 = tt; }
  if (t0 < t1) { tc = c0; c0 = c1; c1 = tc; }
  vec4 col = c0;
  col = c1 + col * (1.0 - c1.a);
  col = c2 + col * (1.0 - c2.a);
  return col;
}

vec4 transition(vec2 uv) {
  float p = progress;
  float s = direction < 0.0 ? -1.0 : 1.0;
  float spacing = ratio * (1.0 + gap);
  // the camera pulls back, glides along the row, and moves back in
  float back = smoothstep(0.0, 0.42, p) * (1.0 - smoothstep(0.58, 1.0, p));
  float m = clamp((p - 0.18) / 0.64, 0.0, 1.0);
  float glide = m * m * m * (m * (m * 6.0 - 15.0) + 10.0);
  float camQ = spacing * glide;
  vec3 o = vec3(s * camQ, 0.0, FOCAL * (1.0 + zoom * back));
  vec3 d = vec3((uv - 0.5) * vec2(ratio, 1.0), -FOCAL);
  float amount = min(1.0, 40.0 * back);
  float aa = max(AA * amount, 1e-6);
  vec4 bg = premultiply(background);

  vec4 col = scene(o, d, s, camQ, spacing, aa, 0.0, bg);
  if (col.a < 1.0) {
    vec4 under = bg;
    // the floor, below the slides, reflects them
    if (d.y < 0.0 && reflection > 0.0) {
      vec4 r = scene(vec3(o.x, -1.0 - o.y, o.z), vec3(d.x, -d.y, d.z), s, camQ, spacing, aa, reflection, bg);
      under = r + bg * (1.0 - r.a);
    }
    // the wall shows around the slides, and only fades in behind their transparent parts,
    // so that the images keep their own alpha at the start and the end
    col += under * (mix(1.0, amount, sceneCover(o, d, s, camQ, spacing, aa)) * (1.0 - col.a));
  }
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
