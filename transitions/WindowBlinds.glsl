// Author: Fabien Benetou
// License: MIT
// Description: The outgoing image is a venetian blind whose slats tilt open in 3D until edge-on, revealing the incoming image behind the window through stripes of light and shadow, then the blind is raised
// Tags: blinds, stripes, 3d

// @range(2, 40, 1) Number of slats
uniform int slats; // = 12
// @param Hang the slats vertically, drawn aside to the right instead of raised
uniform bool vertical; // = false
// @range(0, 1) How much the slats darken as they turn and the shadows they cast
uniform float shading; // = 0.5

const float PI = 3.141592653589793;
const int MAX_SLATS = 40;
// distance from the eye to the window, in frame heights
const float DIST = 2.0;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0015;
// direction toward the light, in (across the slats, toward the viewer): from above and in front
// (from the right and in front for vertical slats)
const vec2 LIGHT = vec2(0.5, 0.866);

float ease(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

// how much the slat centered on c (axis ud, normal nd, half width h) shadows the point q
float shadowOf(vec2 q, vec2 c, vec2 ud, vec2 nd, float h) {
  vec2 d = q - c;
  float dn = dot(LIGHT, nd);
  if (abs(dn) < 1e-4) return 0.0;
  // the ray from q toward the light crosses the slat's plane at t
  float t = -dot(d, nd) / dn;
  if (t <= 0.0) return 0.0;
  float u = dot(d + t * LIGHT, ud);
  // softer the farther the slat
  float pen = 0.003 + 0.06 * t;
  return clamp((h - abs(u)) / pen + 0.5, 0.0, 1.0);
}

vec4 transition (vec2 uv) {
  int count = slats < 1 ? 1 : (slats > MAX_SLATS ? MAX_SLATS : slats);
  float n = float(count);
  // a: across the slats (their stacking axis), b: along them; in frame heights
  float la = vertical ? ratio : 1.0;
  float lb = vertical ? 1.0 : ratio;
  float a = (vertical ? uv.x : uv.y) * la;
  float b = (vertical ? uv.y : uv.x) * lb;
  vec2 eye = vec2(0.5 * la, DIST);
  float eb = 0.5 * lb;
  // the slats' half width and thickness, and their spacing once stacked
  float h = 0.5 * la / n;
  float th = 0.2 * h;
  float stackGap = 1.5 * th;
  // the slats tilt open, then the blind is raised (its stack goes up out of the frame)
  float tilt = ease(progress / 0.6);
  tilt = mix(tilt, sin(0.5 * PI * min(progress / 0.6, 1.0)), 0.4);
  float lift = ease((progress - 0.35) / 0.65);
  float angle = 0.5 * PI * tilt;
  float c = cos(angle), s = sin(angle);
  // axis across a slat (its top edge comes forward) and its front normal, which turns down
  vec2 ud = vec2(c, s);
  vec2 nd = vec2(-s, c);
  // the bottom of the stack, which leaves the frame at the very end (its far side included)
  float rail = mix(-h, eye.x + (0.5 * la + 0.01) * (DIST + h + th) / DIST + th, lift);
  // edges are sharp at rest, to keep the first frame exact
  float w = EDGE * min(1.0, 30.0 * s) + 1e-6;

  // the point of the incoming image behind the window seen through this pixel
  // it is just behind the slats, where the light through them falls between the shadows seen from the eye
  float depth = 1.8 * h;
  vec2 back = vec2(eye.x + (a - eye.x) * (DIST + depth) / DIST, -depth);
  float shadow = 0.0;

  vec4 col1 = vec4(0.0), col2 = vec4(0.0);
  float cov1 = 0.0, cov2 = 0.0;
  float t1 = 1e9, t2 = 1e9;
  for (int k = 0; k < MAX_SLATS; k++) {
    if (k >= count) break;
    float i = float(k);
    float rest = (2.0 * i + 1.0) * h;
    // slat center: it rests at its place until the rising stack collects it
    vec2 ctr = vec2(max(rest, rail + i * stackGap), -0.5 * th);
    shadow = max(shadow, shadowOf(back, ctr, ud, nd, h));

    // the slat's silhouette across, from its 4 corners in perspective
    float amin = 1e9, amax = -1e9;
    for (int j = 0; j < 4; j++) {
      vec2 p = ctr + (j < 2 ? -h : h) * ud + (mod(float(j), 2.0) < 0.5 ? -0.5 : 0.5) * th * nd;
      float ps = eye.x + (p.x - eye.x) * DIST / (DIST - p.y);
      amin = min(amin, ps);
      amax = max(amax, ps);
    }
    if (a < amin - w || a > amax + w) continue;
    float cover = clamp((a - amin) / w + 0.5, 0.0, 1.0) * clamp((amax - a) / w + 0.5, 0.0, 1.0);

    // cast the ray from the eye through the pixel onto the slat (a box in cross-section)
    vec2 ray = vec2(clamp(a, amin, amax) - eye.x, -DIST);
    vec2 q = eye - ctr;
    float u0 = dot(q, ud), ur = dot(ray, ud);
    float v0 = dot(q, nd), vr = dot(ray, nd);
    float tuIn = -1e9, tvIn = -1e9;
    if (abs(ur) > 1e-7) tuIn = min((-h - u0) / ur, (h - u0) / ur);
    if (abs(vr) > 1e-7) tvIn = min((-0.5 * th - v0) / vr, (0.5 * th - v0) / vr);
    float tin = max(tuIn, tvIn);
    if (tin >= t2) continue;
    vec2 hit = eye + tin * ray;
    float u = clamp(dot(hit - ctr, ud), -h, h);
    // along the slat, in perspective
    float bw = eb + (b - eb) * (DIST - hit.y) / DIST;
    cover *= clamp(min(bw, lb - bw) / w + 0.5, 0.0, 1.0);
    if (cover <= 0.0) continue;

    // the face that was hit: front or back, or one of the long edges
    vec2 normal = tvIn >= tuIn ? (vr < 0.0 ? nd : -nd) : (ur < 0.0 ? ud : -ud);
    float lambert = clamp(dot(normal, LIGHT) / LIGHT.y, 0.0, 1.0);
    float shade = mix(1.0 - 0.8 * shading, 1.0, lambert);
    // the shadow of the slat above, on the front face
    if (k + 1 < count) {
      vec2 above = vec2(max(rest + 2.0 * h, rail + (i + 1.0) * stackGap), -0.5 * th);
      shade *= 1.0 - 0.6 * shading * shadowOf(hit, above, ud, nd, h);
    }
    float ta = (rest + u) / la;
    float tb = clamp(bw / lb, 0.0, 1.0);
    vec4 img = getFromColor(vertical ? vec2(ta, tb) : vec2(tb, ta));
    vec4 color = vec4(img.rgb * shade, img.a);
    if (tin < t1) {
      col2 = col1; cov2 = cov1; t2 = t1;
      col1 = color; cov1 = cover; t1 = tin;
    } else {
      col2 = color; cov2 = cover; t2 = tin;
    }
  }

  // stripes of light and shadow through the slats, fading as the blind opens and goes up
  vec4 to = getToColor(uv);
  float dim = 0.8 * shading * shadow * (1.0 - 0.6 * tilt) * (1.0 - lift);
  vec4 bg = vec4(to.rgb * (1.0 - dim), to.a);
  return mix(mix(bg, col2, cov2), col1, cov1);
}
