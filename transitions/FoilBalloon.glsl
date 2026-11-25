// Author: gre
// License: MIT
// Description: The outgoing picture is blown up into a shiny foil balloon, its welded seams drawing in and puckering, its skin catching bright reflections; it floats off, tumbles over in the air, and its back is the incoming picture, which lets the air out and flattens into the frame
// Tags: 3d, balloon, inflate, foil, reflection
// Preview: 0.42

// @range(0.1, 0.5) How far the balloon is blown up
uniform float puff; // = 0.34
// @range(0, 1) Strength of the reflections
uniform float shine; // = 0.85
// @range(0, 1) How much the balloon tumbles as it turns
uniform float tumble; // = 0.6
// @color Background
uniform vec4 sky; // = vec4(0.56, 0.74, 0.88, 1.0)

const float PI = 3.14159265;
const float CAM = 2.4;
// width of the flat welded seam
const float SEAM = 0.022;

vec2 outline(vec2 q, vec2 hs, float air) {
  vec2 k = clamp(abs(q) / hs, 0.0, 1.0);
  return hs * (1.0 - 0.13 * air * (1.0 - k.yx * k.yx));
}

float tall(vec2 q, vec2 hs, float air) {
  vec2 o = outline(q, hs, air) - SEAM * air;
  vec2 k = min(abs(q) / o, 1.0);
  vec2 m = 1.0 - k * k;
  float b = m.x * m.y;
  float dome = 1.45 * b / (b + 0.45);
  vec2 edge = max(o - abs(q), 0.0);
  float wx = sin(q.x * 31.0 + 2.0 * sin(q.x * 9.0)) * exp(-edge.y * 11.0) * smoothstep(0.0, 0.06, edge.y);
  float wy = sin(q.y * 31.0 + 2.0 * sin(q.y * 11.0 + 1.0)) * exp(-edge.x * 11.0) * smoothstep(0.0, 0.06, edge.x);
  return air * (0.004 + puff * dome + 0.018 * (wx + wy) * smoothstep(0.0, 0.1, b));
}

float balloon(vec3 q, vec2 hs, float air) {
  vec2 d = abs(q.xy) - outline(q.xy, hs, air);
  return max(0.4 * (abs(q.z) - tall(q.xy, hs, air)), max(d.x, d.y));
}

vec3 room(vec3 r) {
  float box = smoothstep(0.72, 0.8, r.y + 0.25 * r.x);
  float strip = (1.0 - smoothstep(0.0, 0.1, abs(r.x + 0.55 - 0.2 * r.y))) * smoothstep(-0.4, 0.2, r.y);
  return mix(sky.rgb * 0.45, vec3(1.0), smoothstep(-0.5, 0.9, r.y)) * 0.6 + 0.6 * box + 0.6 * strip;
}

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // blown up in a few puffs
  float fill = smoothstep(0.0, 0.34, p) + 0.05 * sin(clamp(p / 0.34, 0.0, 1.0) * PI * 4.0) * (1.0 - smoothstep(0.2, 0.34, p));
  float air = clamp(fill * (1.0 - smoothstep(0.7, 1.0, p)), 0.0, 1.0);
  vec2 hs = 0.5 * vec2(ratio, 1.0);
  float ph = PI * smoothstep(0.2, 0.84, p);
  float aloft = sin(ph);
  vec2 s = (uv - 0.5) * vec2(ratio, 1.0) * (1.0 + 0.1 * air + 0.45 * aloft);
  s.y -= 0.05 * tumble * air * sin(p * 13.0);
  float roll = tumble * (0.45 * aloft * cos(ph * 0.8) + 0.05 * air * sin(p * 11.0));
  float nod = tumble * (0.75 * aloft * sin(ph * 1.5 - 0.4) + 0.1 * air * sin(p * 9.0));
  vec3 a = vec3(ph, nod, roll);
  vec3 co = cos(a);
  vec3 si = sin(a);
  mat3 my = mat3(co.x, 0.0, si.x, 0.0, 1.0, 0.0, -si.x, 0.0, co.x);
  mat3 mx = mat3(1.0, 0.0, 0.0, 0.0, co.y, si.y, 0.0, -si.y, co.y);
  mat3 mz = mat3(co.z, si.z, 0.0, -si.z, co.z, 0.0, 0.0, 0.0, 1.0);
  mat3 m = my * mx * mz;
  vec3 rd = normalize(vec3(s, -CAM));
  vec3 o = m * vec3(0.0, 0.0, CAM);
  vec3 d = m * rd;

  vec3 box = vec3(hs, air * (puff + 0.06) + 0.01);
  vec3 id = 1.0 / (step(0.0, d) * 2.0 - 1.0) / max(abs(d), 1e-5);
  vec3 tA = (-box - o) * id;
  vec3 tB = (box - o) * id;
  vec3 near = min(tA, tB);
  vec3 far = max(tA, tB);
  // a little slack, so that the silhouette can be antialiased
  float t = max(max(near.x, near.y), near.z) - 0.02;
  float end = min(min(far.x, far.y), far.z) + 0.02;
  float closest = 1e3;
  float at = t;
  for (int i = 0; i < 72; i++) {
    float b = balloon(o + d * t, hs, air);
    if (b < closest) {
      closest = b;
      at = t;
    }
    if (b < 0.0002 || t > end) break;
    t += max(b * 0.9, 0.0006);
  }
  float cover = 1.0 - smoothstep(0.0005, 0.0025, closest);
  // the air behind is lit from above
  vec4 bg = pm(vec4(mix(sky.rgb * 0.85, mix(sky.rgb, vec3(1.0), 0.45), uv.y), sky.a));
  if (cover <= 0.0) return bg.a > 0.0 ? vec4(bg.rgb / bg.a, bg.a) : vec4(0.0);

  // the rest of the way, exact on a flat picture
  vec3 q = o + d * (at + min(closest, 0.0004) * 2.5 / max(abs(d.z), 0.2));
  vec2 out2 = outline(q.xy, hs, air);
  vec2 u = clamp(q.xy / out2 * 0.5 + 0.5, 0.0, 1.0);
  float side = air > 0.0 ? smoothstep(-0.0015, 0.0015, q.z) : step(0.0, o.z);
  side = mix(step(0.0, o.z), side, smoothstep(0.0, 0.05, air));
  vec4 tex = mix(pm(getToColor(vec2(1.0 - u.x, u.y))), pm(getFromColor(u)), side);
  vec2 e = vec2(0.006, 0.0);
  vec3 n = vec3(tall(q.xy - e.xy, hs, air) - tall(q.xy + e.xy, hs, air), tall(q.xy - e.yx, hs, air) - tall(q.xy + e.yx, hs, air), 2.0 * e.x);
  n = normalize(vec3(n.xy, n.z * (2.0 * side - 1.0) + 1e-5));
  vec3 w = n * m;
  vec3 env = room(reflect(rd, w));
  float fres = 0.2 + 0.8 * pow(1.0 - clamp(dot(w, -rd), 0.0, 1.0), 3.0);
  vec2 rim = out2 - abs(q.xy);
  float edge = min(rim.x, rim.y);
  float crease = exp(-abs(edge - SEAM) * 160.0);
  float crimp = (1.0 - smoothstep(0.6 * SEAM, SEAM, edge)) * sin((rim.x < rim.y ? q.y : q.x) * 260.0);
  vec3 foil = tex.rgb * (0.42 + 0.78 * env) * (1.0 - 0.3 * crease + 0.06 * crimp) + env * env * fres * 0.34 * tex.a;
  vec4 c = vec4(mix(tex.rgb, foil, smoothstep(0.0, 0.4, air) * shine), tex.a);
  c = mix(bg, c, cover);
  return c.a > 0.0 ? vec4(min(c.rgb / c.a, 1.0), c.a) : vec4(0.0);
}
