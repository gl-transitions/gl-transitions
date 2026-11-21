// Author: gre
// License: MIT
// Description: The picture becomes a field of overlapping reversible sequins; an unseen hand strokes across it in three sweeps from top to bottom, and the sequins under its round tip turn over in the direction of the stroke with a glint, showing the incoming picture on their backs, while those just outside each sweep lift and fall back
// Tags: sequins, flip, stroke, sparkle, 3d

// @range(8, 40) Rows of sequins stacked across the height of the frame
uniform float rows; // = 16.0
// @range(0, 2) Strength of the glints
uniform float sparkle; // = 1.0

const float PI = 3.14159265;
const float PASSES = 3.0;
const float FLIP = 0.16;
const float PITCH = 1.25;
const float R = 0.75;
const vec3 L = vec3(-0.4504, 0.6006, 0.6606);
const vec3 HALF = vec3(-0.2472, 0.3295, 0.9112);

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float ease(float t) {
  t = clamp(t, 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

float laneDist(vec2 c, float k) {
  return abs(c.y - 1.0 + (k + 0.5) / PASSES - 0.03 * sin(6.0 * c.x + 2.0 * k)) * PASSES;
}

// signed turn of the sequin centred at c (frame heights, y up): positive turns toward +x
float turnAt(vec2 c, float jitter) {
  float own = 0.0, best = 1e3;
  for (int i = 0; i < 3; i++) {
    float m = laneDist(c, float(i));
    if (m < best) { best = m; own = float(i); }
  }
  float a = 0.0;
  for (int i = 0; i < 3; i++) {
    float k = float(i);
    float d = mod(k, 2.0) < 0.5 ? 1.0 : -1.0;
    float along = d > 0.0 ? c.x / ratio : 1.0 - c.x / ratio;
    float m = laneDist(c, k);
    // the round tip reaches the middle of its lane first
    float t = 0.06 + ((k + along) / PASSES + 0.05 * m * m) * 0.62 + jitter;
    float f = (progress - t) / FLIP;
    if (k == own) a += d * PI * ease(f);
    else a += d * 0.8 * clamp(1.0 - 2.5 * (m - 0.5), 0.0, 1.0) * sin(PI * clamp(f * 0.8, 0.0, 1.0));
  }
  return a;
}

vec2 centerOf(vec2 id) {
  return vec2((id.x + 0.5 + 0.5 * mod(id.y, 2.0)) * PITCH, id.y + 0.5);
}

float angleOf(vec2 id) {
  return turnAt(centerOf(id) / rows, 0.02 * hash12(id));
}

// the point of the disc of sequin id, turned by a, seen at p
vec2 poseOf(vec2 p, vec2 id, float a) {
  float sa = sin(a);
  vec2 s = p - centerOf(id) - vec2(0.25 * sa, 0.0);
  return vec2(s.x / max(abs(cos(a)), 0.02), s.y) / (1.0 + 0.25 * abs(sa));
}

float depthOf(vec2 id, float a) {
  // each row hangs over the top of the row below it
  return 2.0 * abs(sin(a)) + 0.01 * id.y;
}

vec4 shadeSequin(vec2 uv, vec2 p, vec2 id, float a, float e) {
  vec2 q = poseOf(p, id, a);
  float ca = cos(a), sa = sin(a);
  bool back = ca < 0.0;
  vec2 src = uv + e * (q - (p - centerOf(id))) / rows / vec2(ratio, 1.0);
  src = 1.0 - abs(1.0 - abs(src));
  vec4 col = back ? getToColor(src) : getFromColor(src);
  float face = back ? -1.0 : 1.0;
  vec3 nrm = normalize(vec3(face * sa + 0.45 * q.x, 0.45 * q.y, abs(ca)));
  float dif = 0.85 + 0.3 * dot(nrm, L) - 0.25 * smoothstep(0.75, 1.0, length(q) / R);
  float spec = pow(max(dot(nrm, HALF), 0.0), 40.0) + 0.6 * pow(abs(sa), 6.0);
  vec3 c = col.rgb * mix(1.0, dif, e) + sparkle * e * spec * vec3(1.0, 0.96, 0.88) * 0.7;
  return vec4(c, col.a);
}

vec4 transition(vec2 uv) {
  float e = ease(progress / 0.08) * ease((1.0 - progress) / 0.08);
  vec2 p = uv * vec2(ratio, 1.0) * rows;
  float aaw = rows / 260.0;
  float j0 = floor(p.y);

  float z1 = -1e3, z2 = -1e3, a1 = 0.0, a2 = 0.0, ang1 = 0.0, ang2 = 0.0;
  vec2 id1 = vec2(0.0), id2 = vec2(0.0);
  float near = 1e3, aHome = 0.0;
  for (int dj = -1; dj <= 1; dj++) {
    float j = j0 + float(dj);
    float i0 = floor(p.x / PITCH - 0.5 * mod(j, 2.0));
    for (int di = -1; di <= 1; di++) {
      vec2 id = vec2(i0 + float(di), j);
      float a = angleOf(id);
      float dc = length(p - centerOf(id));
      if (dc < near) { near = dc; aHome = a; }
      vec2 q = poseOf(p, id, a);
      float r = length(q);
      float squash = mix(1.0, max(abs(cos(a)), 0.02), q.x * q.x / max(r * r, 1e-6));
      float cov = clamp((R - r) * (1.0 + 0.25 * abs(sin(a))) * squash / aaw + 0.5, 0.0, 1.0);
      if (cov <= 0.0) continue;
      float z = depthOf(id, a);
      if (z > z1) {
        z2 = z1; a2 = a1; id2 = id1; ang2 = ang1;
        z1 = z; a1 = cov; id1 = id; ang1 = a;
      } else if (z > z2) {
        z2 = z; a2 = cov; id2 = id; ang2 = a;
      }
    }
  }

  // contact shadows of the sequins lying over each visible layer, cast down and to the right
  float sh1 = 0.0, sh2 = 0.0;
  for (int dj = -1; dj <= 1; dj++) {
    float j = j0 + float(dj);
    float i0 = floor(p.x / PITCH - 0.5 * mod(j, 2.0));
    for (int di = -1; di <= 1; di++) {
      vec2 id = vec2(i0 + float(di), j);
      float a = angleOf(id);
      float z = depthOf(id, a);
      for (int l = 0; l < 2; l++) {
        float zl = l == 0 ? z1 : z2;
        float gap = z - zl;
        if (zl < -1e2 || gap <= 1e-4) continue;
        vec2 q = poseOf(p - vec2(0.08, -0.1) * (1.0 + 2.5 * gap), id, a);
        float s = 1.0 - smoothstep(R - 0.1, R + 0.12 + 0.1 * gap, length(q));
        if (l == 0) sh1 = max(sh1, s); else sh2 = max(sh2, s);
      }
    }
  }

  vec4 under = abs(aHome) > 0.5 * PI ? getToColor(uv) : getFromColor(uv);
  under.rgb *= 1.0 - 0.45 * e;
  vec4 c = under;
  if (a2 > 0.0) {
    vec4 c2 = shadeSequin(uv, p, id2, ang2, e);
    c2.rgb *= 1.0 - 0.4 * e * sh2;
    c = mix(c, c2, a2);
  }
  if (a1 > 0.0) {
    vec4 c1 = shadeSequin(uv, p, id1, ang1, e);
    c1.rgb *= 1.0 - 0.4 * e * sh1;
    c = mix(c, c1, a1);
  }
  return c;
}
