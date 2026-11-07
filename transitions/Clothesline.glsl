// Author: gre
// License: MIT
// Description: The camera pulls back to show the outgoing image as a print hung by two clothespins on a line in front of a wall, the line is pulled sideways and carries it away while the incoming print slides in, both prints swinging and tilting like hanging paper, then the camera moves back in on the incoming print until it fills the frame
// Tags: 3d, perspective, slide, swing, paper, directional

// @param Way the line is pulled: 1 brings the incoming print in from the right, -1 from the left
uniform float direction; // = 1.0
// @range(0, 1) How much the prints swing and tilt as the line moves
uniform float sway; // = 0.5
// @range(0.4, 0.95) Size of the prints when the camera is farthest, as a part of the frame
uniform float size; // = 0.72
// @color Color of the wall behind the line
uniform vec4 background; // = vec4(0.86, 0.84, 0.8, 1.0)
// @color Color of the line
uniform vec4 lineColor; // = vec4(0.42, 0.34, 0.26, 1.0)
// @color Color of the clothespins
uniform vec4 pinColor; // = vec4(0.84, 0.68, 0.47, 1.0)

const float FOCAL = 2.0; // distance from the camera to a print when it fills the frame
const float GAP = 0.35; // space between two prints on the line, in frame heights
const float WALL = 0.14; // distance from the line to the wall behind it
const float ROPE = 0.0055; // half thickness of the line
const vec2 PIN = vec2(0.021, 0.072); // half size of a clothespin
const float PIN_Y = -0.01; // center of a clothespin below the top edge of its print
const float AA = 0.0015; // width of the antialiased edges, in frame heights
const vec3 LIGHT = vec3(-0.28, 0.48, 0.83); // toward the light: above, a bit on the left, in front
const float PIN_X = 0.32; // clothespins from the center of their print, in print widths
const int STEPS = 32; // steps of the swing simulation over the whole transition

// the line moves between these progress values
const float SLIDE_START = 0.1;
const float SLIDE_END = 0.86;

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// time of the line's move at p, from 0 to 1
float slideTime(float p) {
  return clamp((p - SLIDE_START) / (SLIDE_END - SLIDE_START), 0.0, 1.0);
}

// part of its travel done (smootherstep of the time)
float slideAmount(float u) {
  return u * u * u * (u * (u * 6.0 - 15.0) + 10.0);
}

// acceleration of the travel at p, per progress squared
float slideAccel(float p) {
  float u = slideTime(p);
  float dur = SLIDE_END - SLIDE_START;
  return 60.0 * u * (1.0 - u) * (1.0 - 2.0 * u) / (dur * dur);
}

// the sideways swing of the prints' bottoms, along the travel: a damped pendulum driven by the
// line's acceleration, lagging behind it at the start and overshooting at the stop
float swing(float p) {
  const float OMEGA = 10.0; // about 1.6 swings over the transition
  const float DAMP = 0.28;
  const float STEP = 1.0 / float(STEPS);
  float x = 0.0;
  float v = 0.0;
  // fixed steps, the last one cut at p, so that every frame follows the same curve
  for (int i = 0; i < STEPS; i++) {
    float t0 = float(i) * STEP;
    float dt = clamp(p - t0, 0.0, STEP);
    float a = slideAccel(t0 + 0.5 * dt) - OMEGA * OMEGA * x - 2.0 * DAMP * OMEGA * v;
    v += a * dt;
    x += v * dt;
  }
  // it settles as the camera moves back in
  return x * (1.0 - smoothstep(0.7, 1.0, p));
}

// signed distance to a rounded box of half size b and corner radius r
float roundedBox(vec2 q, vec2 b, float r) {
  vec2 d = abs(q) - b + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// the point (u across, v down from the top edge) where the ray o + t d meets the plane of a print
// hanging from (cx, 0.5, 0) and swung back by psi around its top edge, and t
vec3 printHit(vec3 o, vec3 d, float cx, float psi) {
  vec3 dn = vec3(0.0, -cos(psi), -sin(psi));
  vec3 n = vec3(0.0, sin(psi), -cos(psi));
  vec3 p0 = vec3(cx, 0.5, 0.0);
  float t = dot(p0 - o, n) / dot(d, n);
  vec3 q = o + d * t - p0;
  return vec3(q.x, dot(q, dn), t);
}

// the bottom of the print bends sideways by bend frame heights
float bendShift(float v, float bend) {
  float h = clamp(v, 0.0, 1.0);
  return bend * h * (0.6 + 0.4 * h);
}

// signed distance to the paper (negative inside), in frame heights
float paperDist(vec2 uv, float bend) {
  vec2 q = abs(vec2(uv.x - bendShift(uv.y, bend), uv.y - 0.5)) - vec2(0.5 * ratio, 0.5);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// signed distance to the two clothespins of a print
float pinDist(vec2 uv) {
  vec2 q = vec2(abs(uv.x) - PIN_X * ratio, uv.y - PIN_Y);
  return roundedBox(q, PIN, 0.012);
}

// the print hanging at cx over col (premultiplied), then its clothespins
vec4 drawPrint(vec4 col, vec3 h, bool isFrom, float bend, float psi, float aa, float vis) {
  vec2 lp = h.xy;
  float d = paperDist(lp, bend);
  float cov = clamp(0.5 - d / (h.z * aa), 0.0, 1.0);
  if (cov > 0.0) {
    vec2 st = clamp(vec2((lp.x - bendShift(lp.y, bend)) / ratio + 0.5, 1.0 - lp.y), 0.0, 1.0);
    vec4 c = premultiply(isFrom ? getFromColor(st) : getToColor(st));
    // the paper darkens as it swings back and bends, and under the clothespins
    float shade = 1.0 - 1.2 * abs(sin(psi)) * lp.y - 0.35 * abs(bend) * lp.y;
    float ps = pinDist(lp - vec2(0.006, 0.01));
    shade -= 0.35 * vis * (1.0 - smoothstep(-0.004, 0.012, ps));
    c.rgb *= clamp(shade, 0.0, 1.0);
    col = c * cov + col * (1.0 - c.a * cov);
  }
  return col;
}

vec4 drawPins(vec4 col, vec3 h, float aa, float vis) {
  vec2 lp = h.xy;
  float d = pinDist(lp);
  float cov = vis * clamp(0.5 - d / (h.z * aa), 0.0, 1.0);
  if (cov > 0.0) {
    // rounded wood, with the steel spring across it
    float k = clamp((abs(lp.x) - PIN_X * ratio) / PIN.x, -1.0, 1.0);
    vec3 c = pinColor.rgb * (0.62 + 0.45 * sqrt(1.0 - k * k));
    float y = lp.y - PIN_Y;
    float spring = 1.0 - smoothstep(0.004, 0.007, abs(y + 0.02));
    c = mix(c, vec3(0.3, 0.31, 0.33) * (0.6 + 0.8 * sqrt(1.0 - k * k)), spring);
    // the groove that grips the paper
    c *= 1.0 - 0.3 * (1.0 - smoothstep(0.002, 0.005, abs(y - 0.012)));
    vec4 pc = premultiply(vec4(c, pinColor.a));
    col = pc * cov + col * (1.0 - pc.a * cov);
  }
  return col;
}

vec4 transition(vec2 uv) {
  float p = progress;
  float s = direction < 0.0 ? -1.0 : 1.0;
  float sw = clamp(sway, 0.0, 1.0);

  // the camera pulls back, then moves back in on the incoming print
  float back = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.6, 1.0, p));
  float zoom = mix(1.0, clamp(size, 0.1, 1.0), back);
  float vis = smoothstep(0.0, 0.35, back);
  vec3 o = vec3(0.0, 0.05 * back, FOCAL / zoom);
  vec3 d = vec3((uv - 0.5) * vec2(ratio, 1.0), -FOCAL);
  float aa = max(AA * min(1.0, 40.0 * back), 1e-6);

  // the line carries the prints along
  float u = slideTime(p);
  float m = slideAmount(u);
  float speed = 16.0 * u * u * (1.0 - u) * (1.0 - u);
  float spacing = ratio + GAP;
  float cFrom = -s * spacing * m;
  float cTo = s * spacing * (1.0 - m);
  // the bottoms lag behind and overshoot, and swing back in the wind of the move
  float bend = s * 0.65 * sw * swing(p);
  float psi = 0.45 * sw * speed;

  vec3 hf = printHit(o, d, cFrom, psi);
  vec3 ht = printHit(o, d, cTo, psi);

  // the wall, seen around the prints (only behind their transparent parts at the ends),
  // with the soft shadows of the prints, the pins and the line
  vec4 col = premultiply(background);
  float cover = max(
    clamp(0.5 - paperDist(hf.xy, bend) / (hf.z * aa), 0.0, 1.0),
    clamp(0.5 - paperDist(ht.xy, bend) / (ht.z * aa), 0.0, 1.0));
  col *= mix(1.0, back, cover);
  if (back > 0.0) {
    vec3 w = o + d * ((o.z + WALL) / FOCAL);
    vec3 sf = printHit(w, LIGHT, cFrom, psi);
    vec3 st = printHit(w, LIGHT, cTo, psi);
    float blur = 0.025;
    float sh = 1.0 - smoothstep(-blur, blur, min(paperDist(sf.xy, bend), paperDist(st.xy, bend)));
    sh = max(sh, 1.0 - smoothstep(-0.012, 0.02, min(pinDist(sf.xy), pinDist(st.xy))));
    float ry = w.y + LIGHT.y * (WALL / LIGHT.z) - (0.5 - 0.012);
    sh = max(sh, 0.8 * (1.0 - smoothstep(0.0, 0.012, abs(ry))));
    // and a soft falloff of the light away from the top left
    float fall = 0.1 * clamp(length(w.xy - vec2(-0.4 * ratio, 0.6)) / (1.2 * ratio + 0.6), 0.0, 1.0);
    col.rgb *= (1.0 - 0.42 * vis * sh) * (1.0 - fall * vis);
  }

  col = drawPrint(col, hf, true, bend, psi, aa, vis);
  col = drawPrint(col, ht, false, bend, psi, aa, vis);

  // the line, in front of the top of the prints
  if (vis > 0.0) {
    float tl = (o.z - 0.004) / FOCAL;
    float ly = o.y + d.y * tl - (0.5 - 0.012);
    float lc = vis * clamp(0.5 - (abs(ly) - ROPE) / (tl * aa), 0.0, 1.0);
    if (lc > 0.0) {
      float k = clamp(ly / ROPE, -1.0, 1.0);
      // twisted strands, carried along with the line, lit from above
      float lx = o.x + d.x * tl + s * spacing * m;
      float strand = 0.88 + 0.12 * sin((lx + ly * 0.6) * 360.0);
      vec3 c = lineColor.rgb * (0.7 + 0.45 * sqrt(1.0 - k * k) + 0.15 * k) * strand;
      vec4 lcp = premultiply(vec4(c, lineColor.a));
      col = lcp * lc + col * (1.0 - lcp.a * lc);
    }
    col = drawPins(col, hf, aa, vis);
    col = drawPins(col, ht, aa, vis);
  }
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
