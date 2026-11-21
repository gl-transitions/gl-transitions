// Author: gre
// License: MIT
// Description: The outgoing picture is a closed bud: it parts into overlapping petals from its middle, and the petals curl back and open outward like a flower blooming, the outer whorl first and the inner one just after, onto the incoming picture
// Tags: organic, flower, petals, radial, 3d, shadow

// @range(2, 8, 1) Number of petals in each of the two whorls
uniform int petals; // = 4
// @range(0.5, 5.0) How strongly the petals curl back as they open
uniform float curl; // = 3.0
// @range(0.2, 0.9) How far each petal overlaps its neighbours at its widest
uniform float overlap; // = 0.55
// @range(-1.0, 1.0) How far the petals turn around the middle while opening, in radians
uniform float twist; // = 0.3

const float PI = 3.14159265;
const float TIP = 0.04;
const vec3 LIGHT = vec3(-0.42, 0.5, 0.757);

float ease(float x) {
  x = clamp(x, 0.0, 1.0);
  float x4 = x * x * x * x;
  return 0.78 * x + 0.22 * x4 * x4;
}

vec2 mirrorUv(vec2 v) { return 1.0 - abs(1.0 - mod(v, 2.0)); }

// w = (h, k, sin h, opening) of the whorl; returns x: coverage, y: unfolded radius, z: unfolded angle, w: surface tilt
vec4 petal(float r, float ang, float j, vec4 w, float da, float tw, float R, float soft) {
  float off = ang - tw - j * da;
  off -= 2.0 * PI * floor(off / (2.0 * PI) + 0.5);
  float arg = w.z + w.y * (R - r);
  float a = asin(min(arg, 1.0));
  float m = R - (a - w.x) / w.y;
  float psi = off * r / max(m, 1e-4);
  float u = clamp(m / R, 0.0, 1.0);
  // rounded tips overlap at the middle so no star-shaped gap opens there
  float hw = max(0.5 * da * (1.04 + overlap * (1.0 - u * u)), TIP / max(m, 1e-4));
  float aa = (0.0025 + soft) * min(1.0, 30.0 * w.w) + 1e-6;
  float cov = (1.0 - smoothstep(1.0 - 2.0 * w.y * aa, 1.0, arg))
    * smoothstep(0.0, aa, (hw - abs(psi)) * m + 1e-5)
    * smoothstep(0.0, aa, m);
  return vec4(cov, m, j * da + psi, a);
}

vec4 whorl(float f) {
  float h = 0.5 * PI * f * f;
  // k must stay > 0 for the unbend; tiny so the closed bud is exact
  return vec4(h, max(curl * f * (2.0 - f), 1e-3), sin(h), f);
}

vec4 shade(vec4 pe, float axis) {
  vec2 q = 0.5 + pe.y * vec2(cos(pe.z), sin(pe.z));
  vec4 c = getFromColor(mirrorUv(q));
  float lambert = cos(pe.w) * LIGHT.z - sin(pe.w) * dot(vec2(cos(axis), sin(axis)), LIGHT.xy);
  c.rgb *= mix(0.3, 1.0, clamp(lambert / LIGHT.z, 0.0, 1.2));
  return c;
}

vec4 over(vec4 c, vec4 pe, float axis, float dim) {
  vec4 pc = shade(pe, axis);
  pc.rgb *= 1.0 - dim;
  return mix(c, pc, pe.x);
}

// nearest slot of the given parity and the next one on the pixel's side
vec2 pair(float s, float parity) {
  float j = 2.0 * floor((s - parity) / 2.0 + 0.5) + parity;
  return vec2(j, j + (s >= j ? 2.0 : -2.0));
}

vec4 transition(vec2 uv) {
  // offset keeps atan away from (0, 0) on odd-sized frames
  vec2 p = uv - 0.5 + vec2(1e-5, 0.0);
  float R = 0.73;
  float da = PI / float(petals);
  float t = progress;
  float tw = twist * ease(t);
  vec4 wo = whorl(ease(t / 0.93));
  vec4 wi = whorl(ease((t - 0.07) / 0.93));
  float env = sin(PI * t);

  float r = length(p);
  float ang = atan(p.y, p.x);
  float s = (ang - tw) / da;
  // even slots are the outer whorl, which opens first and curls back behind the inner one
  vec2 jo = pair(s, 0.0);
  vec2 ji = pair(s, 1.0);
  vec4 o1 = petal(r, ang, jo.x, wo, da, tw, R, 0.0);
  vec4 o2 = petal(r, ang, jo.y, wo, da, tw, R, 0.0);
  vec4 i1 = petal(r, ang, ji.x, wi, da, tw, R, 0.0);
  vec4 i2 = petal(r, ang, ji.y, wi, da, tw, R, 0.0);

  vec2 ps = p + 0.045 * env * LIGHT.xy;
  float rs = length(ps);
  float angs = atan(ps.y, ps.x);
  float ss = (angs - tw) / da;
  vec2 kso = pair(ss, 0.0);
  vec2 ksi = pair(ss, 1.0);
  float shI = max(petal(rs, angs, ksi.x, wi, da, tw, R, 0.02).x, petal(rs, angs, ksi.y, wi, da, tw, R, 0.02).x);
  float shO = max(petal(rs, angs, kso.x, wo, da, tw, R, 0.02).x, petal(rs, angs, kso.y, wo, da, tw, R, 0.02).x);

  vec4 c = getToColor(uv);
  c.rgb *= 1.0 - 0.5 * env * max(shI, shO);
  float dim = 0.45 * env * shI;
  c = over(c, o2, jo.y * da + tw, dim);
  c = over(c, o1, jo.x * da + tw, dim);
  c = over(c, i2, ji.y * da + tw, 0.0);
  return over(c, i1, ji.x * da + tw, 0.0);
}
