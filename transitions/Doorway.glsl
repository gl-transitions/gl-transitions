// Author: gre
// License: MIT
// Description: The outgoing image opens like double doors swinging toward the viewer, as the incoming one comes forward from the dark room behind, with a floor reflection
// Tags: doors, 3d, reflection

// @range(0, 1) Strength of the floor reflection under the incoming image
uniform float reflection; // = 0.4
// @range(0, 1) Amount of perspective on the swinging doors
uniform float perspective; // = 0.4
// @range(1, 10) How far back the incoming image starts (1: no distance)
uniform float depth; // = 3

const float PI = 3.141592653589793;

// cast the view ray of screen point x (aspect units, the frame is 0..w) onto a leaf of
// width w/2 hinged on the left edge and turned toward the viewer by angle a.
// The eye is at (w/2, 0.5, -eye) and the frame at z = 0; returns (t, distance along the leaf)
// where t scales the ray so that t = 1 is the frame plane
vec2 leafHit (float x, float w, float eye, float a) {
  float c = cos(a), s = sin(a);
  float t = (eye * c - 0.5 * w * s) / (s * (x - 0.5 * w) + eye * c);
  vec2 hit = vec2(0.5 * w + t * (x - 0.5 * w), eye * (t - 1.0));
  return vec2(t, hit.x * c - hit.y * s);
}

// screen x of a point (x, z) seen from the eye
float project (vec2 p, float w, float eye) {
  return 0.5 * w + (p.x - 0.5 * w) * eye / (eye + p.y);
}

float easeInOut (float t) {
  return t < 0.5 ? 4.0 * t * t * t : 1.0 - 4.0 * (1.0 - t) * (1.0 - t) * (1.0 - t);
}

// the room behind: the incoming image coming forward, and its reflection on the floor
vec4 room (vec2 uv, float x, float edgeL, float edgeR, float close, float dolly) {
  float size = mix(max(depth, 1.0), 1.0, dolly);
  vec2 p = (uv - 0.5) * size + 0.5;
  // soft border while it is far, exactly sharp once it fills the frame
  float soft = 0.004 * (size - 1.0) + 1e-6;
  vec2 m = smoothstep(-soft, soft, p) * smoothstep(-soft, soft, 1.0 - p);
  vec4 c = getToColor(clamp(p, 0.0, 1.0)) * (m.x * m.y);
  if (p.y < 0.0) {
    vec2 r = vec2(p.x, -1.2 * p.y - 0.02);
    float f = reflection * (1.0 - r.y) * m.x * smoothstep(0.0, 0.01, r.y);
    c += getToColor(clamp(r, 0.0, 1.0)) * f * (1.0 - m.y);
  }
  // the lit room spills its light through the opening, and the leaves cast soft shadows
  // along their edges; both settle as the doors open
  float wl = 0.03 + 0.12 * close;
  float shadow = (1.0 - smoothstep(0.0, wl, x - edgeL)) + (1.0 - smoothstep(0.0, wl, edgeR - x));
  float light = (1.0 + 0.6 * close * close) * (1.0 - 0.7 * close * min(shadow, 1.0));
  return vec4(min(c.rgb * light, vec3(c.a)), c.a);
}

vec4 transition (vec2 uv) {
  float w = ratio;
  float x = uv.x * w;
  // camera distance: the leaves always stay in front of it
  float eye = max(w, 1.0) * (0.5 + 0.2 / max(perspective, 0.01));
  // the leaves swing until their free edges have just left the frame
  float swing = progress * progress * (3.0 - 2.0 * progress);
  float a = min(atan(2.0 * eye / w) + 0.1, 0.5 * PI) * swing;
  float dolly = mix(easeInOut(progress), progress, 0.3);
  // the free edge of the left leaf, front and back of its thickness, as (x, z)
  float hw = 0.5 * w;
  vec2 front = hw * vec2(cos(a), -sin(a));
  float thick = 0.02 * w * (1.0 - smoothstep(0.8, 1.0, swing));
  float edgeL = project(front, w, eye);
  float backL = project(front + thick * vec2(sin(a), cos(a)), w, eye);
  float close = 1.0 - swing;
  vec4 back = room(uv, x, backL, w - backL, close, dolly);
  // the leaf on this side of the frame (each one stays in its own half)
  bool left = x < hw;
  float lx = left ? x : w - x;
  vec2 hit = leafHit(lx, w, eye, a);
  float s = clamp(hit.y, 0.0, hw);
  // the ray meets the leaf nearer to the eye, where it looks bigger
  float v = 0.5 + (uv.y - 0.5) * hit.x;
  vec4 leaf = getFromColor(clamp(vec2(left ? s / w : 1.0 - s / w, v), 0.0, 1.0));
  // turned away from the light, and darker toward the free edge as the opening deepens
  leaf.rgb *= 1.0 - 0.5 * (1.0 - cos(a)) - 0.25 * sin(a) * (s / hw);
  // the edge of the leaf catches the light coming from the room
  vec4 side = getFromColor(clamp(vec2(left ? 0.499 : 0.501, v), 0.0, 1.0));
  side.rgb = min(side.rgb * 1.5, vec3(side.a));
  // sharp at both ends, so that nothing of the doors is left at the start and the end
  float aa = 0.003 * min(1.0, 20.0 * min(a, close)) + 1e-6;
  vec4 c = mix(back, side, smoothstep(-aa, aa, backL - lx));
  return mix(c, leaf, smoothstep(-aa, aa, edgeL - lx));
}
