// Author: gre
// License: MIT
// Description: The outgoing image is a sheet of paper that folds in half in 3D along a vertical crease, then in half again along a horizontal one, its lit and shaded faces turning to show the back of the paper, and the small folded packet flies off the frame, leaving its shadow on the incoming image underneath
// Tags: paper, fold, 3d, shadow

// @param Direction the folded packet flies off toward
uniform vec2 direction; // = vec2(1.0, 0.5)
// @range(0, 1) How much the sheet tilts and recedes while it folds, so that the folds are seen in 3D
uniform float tilt; // = 0.6
// @range(0, 1) How much the faces darken as they turn away from the light, and the shadows they cast
uniform float shading; // = 0.6
// @color Color of the back of the paper, through which the print faintly shows
uniform vec4 paper; // = vec4(0.95, 0.94, 0.9, 1.0)

const float PI = 3.141592653589793;
// width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0015;
// how much the print shows through the back of the paper
const float SHOW = 0.1;
// width of the shaded crease, in frame heights
const float CREASE = 0.02;
// direction of the light, from the top left and the front
const vec3 LIGHT = vec3(-0.3995, 0.4494, 0.799);

vec4 front(vec2 st) {
  return getFromColor(st / vec2(ratio, 1.0));
}

vec4 back(vec2 st) {
  vec4 c = front(st);
  return vec4(mix(paper.rgb, c.rgb, SHOW), c.a * paper.a);
}

// the face of the packet's top layer: the image itself during the first fold, then the back
// of the right half, laid mirrored over the left half
vec4 topFace(vec2 st, bool second) {
  return second ? back(vec2(ratio - st.x, st.y)) : front(st);
}

// distance inside the rectangle [0, h] x [0, k] (negative outside)
float inside(vec2 p, float h, float k) {
  return min(min(p.x, h - p.x), min(p.y, k - p.y));
}

// The sheet in its own frame: a flat part [0, h] x [0, k] lying at z = 0 and a flap of the same
// size hinged on its edge x = h, turned toward the viewer so that it lies along `along`, with the
// normal n. During the second fold, x and y are swapped so that the crease is always along y.
// Where the ray o + t * v meets the flap's plane: (t, distance from the hinge, y), t < 0 if never.
vec3 hitFlap(vec3 o, vec3 v, float h, vec3 n, vec3 along) {
  float den = dot(n, v);
  if (abs(den) < 1e-5) return vec3(-1.0, 0.0, 0.0);
  vec3 hinge = vec3(h, 0.0, 0.0);
  float t = dot(n, hinge - o) / den;
  vec3 q = o + t * v;
  return vec3(t, dot(q - hinge, along), q.y);
}

// how much the point q is shaded, lit by l: by the flap, and by the flat part once it lifts
// above the incoming image
float shadowAt(vec3 q, vec3 l, float h, float k, vec3 n, vec3 along) {
  float sh = 0.0;
  if (q.z < -1e-4) {
    float soft = 0.004 - 0.4 * q.z;
    sh = smoothstep(-soft, soft, inside(q.xy - q.z / l.z * l.xy, h, k));
  }
  vec3 hit = hitFlap(q, l, h, n, along);
  if (hit.x > 0.0) {
    float height = hit.x * l.z;
    float soft = 0.004 + 0.3 * height;
    // the flap's shadow appears as it lifts and vanishes as it lands
    sh = max(sh, min(4.0 * n.x * n.x, 1.0) * smoothstep(-soft, soft, inside(hit.yz, h, k)) / (1.0 + 3.0 * height));
  }
  return sh;
}

// a vector of the frame into the frame of the sheet, turned by yaw (around y), pitch (around x)
// and spin (around z), each given as (cos, sin)
vec3 toSheet(vec3 v, vec2 yaw, vec2 pitch, vec2 spin) {
  v = vec3(yaw.x * v.x + yaw.y * v.z, v.y, yaw.x * v.z - yaw.y * v.x);
  v = vec3(v.x, pitch.x * v.y + pitch.y * v.z, pitch.x * v.z - pitch.y * v.y);
  return vec3(spin.x * v.x + spin.y * v.y, spin.x * v.y - spin.y * v.x, v.z);
}

vec4 transition(vec2 uv) {
  float w = ratio;
  float shade = clamp(shading, 0.0, 1.0);
  // the two folds, one right after the other, then the flight of the packet
  float s = 2.0 * smoothstep(0.0, 0.62, progress);
  bool second = s > 1.0;
  float x = second ? s - 1.0 : s;
  float a = PI * mix(x, x * x * (3.0 - 2.0 * x), 0.6);
  float f = clamp((progress - 0.5) / 0.47, 0.0, 1.0);

  // the sheet tilts and recedes while it folds, so that the folds are seen in 3D, and lies flat
  // again as the packet flies off
  float turn = clamp(tilt, 0.0, 1.0) * (smoothstep(0.0, 0.25, progress) - smoothstep(0.4, 0.8, progress));
  vec2 yaw = vec2(cos(0.45 * turn), sin(0.45 * turn));
  vec2 pitch = vec2(cos(0.55 * turn), -sin(0.55 * turn));
  float dist = 2.5 * max(w, 1.0);
  float recede = dist * 0.35 * turn;

  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  // the point of the sheet held in the middle of the frame slides to the middle of the packet
  vec2 c = vec2(0.5 * w - 0.25 * w * min(s, 1.0), 0.5 - 0.25 * max(s - 1.0, 0.0));
  // far enough for the packet and its shadow to leave the frame
  float reach = 0.5 * (abs(dir.x) * w + abs(dir.y)) + length(vec2(0.25 * w, 0.25)) + 0.4;
  float lift = 0.3 * smoothstep(0.0, 0.5, f);
  float turned = (dir.x < 0.0 ? 0.7 : -0.7) * f * f;
  vec2 spin = vec2(cos(turned), sin(turned));

  // the eye, the ray toward the point of the frame and the light, in the frame of the sheet,
  // where the sheet lies on the plane z = 0 and the incoming image on z = -lift
  vec3 center = vec3(vec2(0.5 * w, 0.5) + dir * reach * f * f, -recede);
  vec3 eye = vec3(0.5 * w, 0.5, dist);
  vec3 e = toSheet(eye - center, yaw, pitch, spin) + vec3(c, 0.0);
  vec3 d = toSheet(vec3(uv.x * w, uv.y, 0.0) - eye, yaw, pitch, spin);
  vec3 l = toSheet(LIGHT, yaw, pitch, spin);
  if (second) {
    e.xy = e.yx;
    d.xy = d.yx;
    l.xy = l.yx;
  }
  float h = second ? 0.5 : 0.5 * w;
  float k = second ? 0.5 * w : 1.0;
  float creased = sin(a);
  vec3 n = vec3(-creased, 0.0, cos(a));
  vec3 along = vec3(cos(a), 0.0, creased);

  vec4 col = getToColor(uv);
  if (d.z < 0.0) {
    vec3 g = e + d * (e.z + lift) / -d.z;
    // the shadow fades as the packet flies higher
    col.rgb *= 1.0 - 0.7 * shade * (1.0 - f * f) * shadowAt(g, l, h, k, n, along);
  }

  // the flat part
  float t = d.z < 0.0 ? e.z / -d.z : -1.0;
  vec3 p = e + t * d;
  float m = clamp(inside(p.xy, h, k) / (EDGE * t) + 1.0, 0.0, 1.0);
  if (t > 0.0 && m > 0.0) {
    vec4 img = topFace(second ? p.yx : p.xy, second);
    float sh = shadowAt(p, l, h, k, n, along);
    img.rgb *= (1.0 - 0.7 * shade * sh) * (1.0 - 0.5 * shade * creased * exp(-abs(h - p.x) / CREASE));
    col = mix(col, img, m);
  }

  // the flap
  vec3 hit = hitFlap(e, d, h, n, along);
  if (hit.x > 0.0) {
    float r = hit.y;
    // edges seen at a grazing angle are narrower on screen
    float dr = dot(along, normalize(d));
    float fore = sqrt(max(1.0 - dr * dr, 0.0025));
    float mf = clamp(min(min(r, h - r) * fore, min(hit.z, k - hit.z)) / (EDGE * hit.x) + 1.0, 0.0, 1.0);
    if (mf > 0.0) {
      bool up = dot(n, e - vec3(h, 0.0, 0.0)) > 0.0;
      vec2 st = vec2(h + r, hit.z);
      if (second) st = st.yx;
      vec4 img = up ? topFace(st, second) : back(st);
      // lit by the light, relative to the sheet lying flat
      float lit = dot(up ? n : -n, l) - l.z;
      img.rgb *= max(1.0 + 0.6 * shade * lit, 0.0) * (1.0 - 0.5 * shade * creased * exp(-abs(r) / CREASE));
      col = mix(col, img, mf);
    }
  }
  return col;
}
