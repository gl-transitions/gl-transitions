// Author: gre
// License: MIT
// Description: The two images are faces of a box that turns a quarter turn in perspective, the outgoing face darkening as it turns away, above a reflective floor
// Tags: 3d, cube, rotate, reflection
// @range(0, 1) Amount of perspective
uniform float persp; // = 0.7
// @range(0, 1) How far the camera pulls back mid-turn, as a part of the frame
uniform float unzoom; // = 0.3
// @range(0, 1) Strength of the reflection
uniform float reflection; // = 0.4
// @range(0, 20) Gap between the box and its reflection, as a percentage of the frame height
uniform float floating; // = 3.0
// @range(0, 1) How much the faces darken as they turn away, and the shadow on the floor
uniform float shading; // = 0.5

const float PI = 3.141592653589793;
// width of the anti-aliased edges, as a part of the frame's height at the box's front
const float EDGE = 0.002;

// the ray (eye, dir) in the box's frame, the box turned by (c, s) around its vertical axis:
// returns (distance along the ray, horizontal position on the face, height, face) with face 0 for
// the outgoing image's face, 1 for the incoming one's, and a negative distance where it misses
vec4 hitBox(vec3 eye, vec3 dir, float w, float c, float s) {
  vec2 pivot = vec2(0.5 * w);
  vec2 e = eye.xz - pivot;
  vec2 o = vec2(e.x * c + e.y * s, -e.x * s + e.y * c) + pivot;
  vec2 d = vec2(dir.x * c + dir.z * s, -dir.x * s + dir.z * c);
  // the side faces seen from outside: the box spans [0, w] on x and z
  vec2 inv = 1.0 / vec2(d.x < 0.0 ? min(d.x, -1e-6) : max(d.x, 1e-6), d.y < 0.0 ? min(d.y, -1e-6) : max(d.y, 1e-6));
  vec2 t0 = (vec2(0.0) - o) * inv;
  vec2 t1 = (vec2(w) - o) * inv;
  vec2 tn = min(t0, t1);
  vec2 tf = max(t0, t1);
  float tin = max(tn.x, tn.y);
  if (tin <= 0.0 || tin > min(tf.x, tf.y)) return vec4(-1.0);
  vec2 hit = o + tin * d;
  float y = eye.y + tin * dir.y;
  if (y < 0.0 || y > 1.0) return vec4(-1.0);
  // the face first entered: z = 0 is the outgoing face, x = 0 the incoming one, the others are hidden
  if (tn.y >= tn.x) {
    if (d.y <= 0.0) return vec4(-1.0);
    return vec4(tin, hit.x / w, y, 0.0);
  }
  if (d.x <= 0.0) return vec4(-1.0);
  return vec4(tin, 1.0 - hit.y / w, y, 1.0);
}

vec4 transition(vec2 uv) {
  float w = ratio;
  // the turn starts and ends softly
  float turn = progress * progress * (3.0 - 2.0 * progress);
  float a = 0.5 * PI * turn;
  float c = cos(a), s = sin(a);
  if (progress >= 1.0) { c = 0.0; s = 1.0; }
  // 0 at both ends, for exact images and hard edges there
  float motion = sin(PI * clamp(progress, 0.0, 1.0));
  float zoom = 1.0 + max(unzoom, 0.0) * motion;

  // the front of the box is the screen: the camera keeps it framed, pulling back mid-turn
  float dist = 0.8 * max(w, 1.0) / clamp(persp, 0.01, 1.0);
  vec3 eye = vec3(0.5 * w, 0.5, -dist);
  vec2 sp = (uv - 0.5) * zoom + 0.5;
  vec3 dir = vec3(sp.x * w, sp.y, 0.0) - eye;

  // pixel footprint on the screen plane, for the anti-aliased edges
  float px = EDGE * zoom * min(10.0 * motion, 1.0);
  float shade0 = 1.0 - shading * (1.0 - c);
  float shade1 = 1.0 - shading * (1.0 - s);

  // the box in front, premultiplied
  vec4 front = vec4(0.0);
  vec4 b = hitBox(eye, dir, w, c, s);
  if (b.x > 0.0) {
    vec4 img = b.w < 0.5 ? getFromColor(vec2(b.y, b.z)) : getToColor(vec2(b.y, b.z));
    float m = 1.0;
    if (px > 0.0) {
      // the silhouette: top, bottom and the outer vertical edge of the face, seen foreshortened
      float e = px * b.x;
      vec3 n = b.w < 0.5 ? vec3(s, 0.0, -c) : vec3(-c, 0.0, -s);
      float fore = max(abs(dot(n, normalize(dir))), 0.05);
      float edge = b.w < 0.5 ? 1.0 - b.y : b.y;
      m = clamp(min(b.z, 1.0 - b.z) / e, 0.0, 1.0)
        * clamp(edge * w * fore / e, 0.0, 1.0);
    }
    // where the box covers the pixel, nothing behind it shows: the exact image at both ends
    if (m >= 1.0 && img.a >= 1.0) {
      return vec4(img.rgb * (b.w < 0.5 ? shade0 : shade1), img.a);
    }
    front = vec4(img.rgb * (b.w < 0.5 ? shade0 : shade1) * img.a, img.a) * m;
  }

  // the floor, h below the box, premultiplied; it fades in and out with the motion
  vec4 ground = vec4(0.0);
  float h = 0.005 * max(floating, 0.0);
  if (dir.y < 0.0 && motion > 0.0) {
    float tf = -(eye.y + h) / dir.y;
    vec3 f = eye + tf * dir;
    // the reflection: the same ray mirrored by the floor, fading with the height on the box
    vec3 meye = vec3(eye.x, -2.0 * h - eye.y, eye.z);
    vec3 mdir = vec3(dir.x, -dir.y, dir.z);
    vec4 r = hitBox(meye, mdir, w, c, s);
    if (r.x > 0.0) {
      vec4 img = r.w < 0.5 ? getFromColor(vec2(r.y, r.z)) : getToColor(vec2(r.y, r.z));
      float k = clamp(reflection, 0.0, 1.0) * (1.0 - r.z) * (1.0 - r.z);
      ground = vec4(img.rgb * (r.w < 0.5 ? shade0 : shade1) * img.a, img.a) * k;
    }
    // the contact shadow around the box, softer as it floats higher
    vec2 q = f.xz - vec2(0.5 * w);
    vec2 l = vec2(q.x * c + q.y * s, -q.x * s + q.y * c);
    float soft = 0.03 + 1.5 * h;
    float sh = shading * 0.7 * exp(-length(max(abs(l) - vec2(0.5 * w), 0.0)) / soft);
    // only as opaque as the bottom of the nearest face
    vec2 bl = l + vec2(0.5 * w);
    sh *= l.y < l.x
      ? getFromColor(vec2(clamp(bl.x / w, 0.0, 1.0), 0.0)).a
      : getToColor(vec2(clamp(1.0 - bl.y / w, 0.0, 1.0), 0.0)).a;
    ground = ground * (1.0 - sh) + vec4(0.0, 0.0, 0.0, sh);
    ground *= min(6.0 * motion, 1.0);
  }

  vec4 color = front + ground * (1.0 - front.a);
  return color.a > 0.0 ? vec4(color.rgb / color.a, color.a) : vec4(0.0);
}
