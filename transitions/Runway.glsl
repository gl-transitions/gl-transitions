// Author: gre
// License: MIT
// Description: As the outgoing image falls over backward onto a glossy floor and becomes the ground, the camera rises with it, looks down on it and travels over it toward the incoming image, which stands at its far edge mirrored in its surface, and tilts back up as the incoming image fills the frame
// Tags: 3d, camera, perspective, floor, reflection

// @range(0, 1) How high the camera rises and how far it looks down while it travels
uniform float lift; // = 0.7
// @range(0, 1) Strength of the incoming image's reflection on the fallen image and the floor
uniform float reflection; // = 0.35

const float F = 1.5;
const float PI = 3.14159265;

// a dim room lit by the pictures: their average color, brighter toward the horizon
vec4 haze(vec3 d, float w) {
  vec4 ca = vec4(0.0);
  vec4 cb = vec4(0.0);
  for (int i = 0; i < 4; i++) {
    float k = float(i);
    vec2 q = 0.5 + (0.15 + 0.07 * k) * vec2(cos(k * 2.4), sin(k * 2.4));
    vec4 fa = getFromColor(q);
    vec4 fb = getToColor(q);
    ca += vec4(fa.rgb * fa.a, fa.a);
    cb += vec4(fb.rgb * fb.a, fb.a);
  }
  vec4 c = mix(ca, cb, w);
  float e = d.y / length(d);
  return vec4(c.rgb / max(c.a, 1e-4) * (0.36 + 0.42 * exp(-8.0 * e * e)), c.a / 4.0);
}

// ray against the incoming image standing at z = 1: (u, v, t)
vec3 hitTo(vec3 o, vec3 d) {
  float t = (1.0 - o.z) / d.z;
  vec3 h = o + d * t;
  return vec3(h.x / ratio + 0.5, h.y, d.z > 0.0 ? t : -1.0);
}

// antialiased coverage of the unit square at q, for a hit at distance t
float cover(vec2 q, float t, float aa) {
  vec2 e = min(q, 1.0 - q) * vec2(ratio, 1.0);
  return t > 0.0 ? clamp(0.5 + min(e.x, e.y) * F / (t * aa), 0.0, 1.0) : 0.0;
}

vec3 mirrored(vec3 o, vec3 r) {
  vec3 h = hitTo(o, r);
  if (h.z <= 0.0 || h.x < 0.0 || h.x > 1.0 || h.y < 0.0 || h.y > 1.0) return vec3(0.0);
  vec4 c = getToColor(h.xy);
  return c.rgb * c.a * (1.0 - h.y);
}

vec4 transition(vec2 uv) {
  float p = progress;
  float s = clamp(p / 0.4, 0.0, 1.0);
  float b = clamp((p - 0.4) / 0.14, 0.0, 1.0);
  // polynomial rebound, exactly 0 once settled whatever the precision of PI
  float a = 0.5 * PI * s * s - 0.24 * b * (1.0 - b);
  // the camera rises and tilts down from the very start, peaking early so most of the move is the glide
  float x = 1.0 - (1.0 - p) * sqrt(1.0 - p);
  float env = sin(PI * x);
  env *= env;
  float m = smoothstep(0.05, 1.0, p);
  float pitch = 0.75 * lift * env;
  vec3 o = vec3(0.0, 0.5 + 1.1 * lift * env, -F + m);
  vec3 fw = vec3(0.0, -sin(pitch), cos(pitch));
  vec3 up = vec3(0.0, cos(pitch), sin(pitch));
  vec3 d = vec3((uv.x - 0.5) * ratio, 0.0, 0.0) + up * (uv.y - 0.5) + fw * F;
  float aa = max(0.0025 * min(1.0, 120.0 * p * (1.0 - p)), 1e-4);
  float w = smoothstep(0.2, 0.8, p);

  vec4 c = haze(d, w);
  if (d.y < 0.0) {
    vec3 hg = o - d * (o.y / d.y);
    // the standing outgoing image hides the incoming one from the floor until it lies down
    c.rgb = c.rgb * 0.55 + 0.5 * reflection * sin(a) * mirrored(hg, vec3(d.x, -d.y, d.z));
  }

  vec3 ht = hitTo(o, d);
  c = mix(c, getToColor(ht.xy), cover(ht.xy, ht.z, aa));

  vec3 along = vec3(0.0, cos(a), sin(a));
  vec3 n = vec3(0.0, -sin(a), cos(a));
  float dn = dot(d, n);
  float tf = -dot(o, n) / (abs(dn) < 1e-4 ? (dn < 0.0 ? -1e-4 : 1e-4) : dn);
  vec3 hf = o + d * tf;
  vec2 qf = vec2(hf.x / ratio + 0.5, dot(hf, along));
  vec4 f = getFromColor(qf);
  float lie = sin(a);
  f.rgb *= (1.0 - 0.2 * lie) * (1.0 - 0.5 * lie * exp(-10.0 * abs(1.0 - qf.y)));
  f.rgb += reflection * lie * 0.6 * mirrored(hf, reflect(d, n));
  return mix(c, f, cover(qf, tf, aa));
}
