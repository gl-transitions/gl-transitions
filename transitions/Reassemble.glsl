// Author: gre
// License: MIT
// Description: The outgoing image cracks into irregular shards that burst apart toward the viewer, each one turning over in 3D at its own moment, then fly back together and lock into place as the incoming image carried on their backs
// Tags: 3d, shards, flip, explode

// @range(2, 8, 1) Number of rows of shards
uniform int rows; // = 4
// @range(0, 1) How far the shards come toward the viewer
uniform float depth; // = 0.8
// @range(0, 0.5) How far the shards spread apart, as a part of their distance from the center
uniform float spread; // = 0.05
// @color Color seen between the shards
uniform vec4 backColor; // = vec4(0.04, 0.04, 0.05, 1.0)

const float PI = 3.141592653589793;
// distance of the eye, in frame heights
const float EYE = 2.5;
// width of the anti-aliased edges and half width of the open cracks, in frame heights
const float EDGE = 0.0015;
const float CRACK = 0.005;
// the shards leave between START and START + DELAY, and each one flies for FLIGHT
const float START = 0.03;
const float DELAY = 0.08;
const float FLIGHT = 0.86;

vec3 hash3(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yxz + 33.33);
  return fract((q.xxy + q.yzz) * q.zyx);
}

// the seed of the shard of grid cell g, in frame heights from the center
vec2 seed(vec2 g, float size) {
  return (g + 0.5 + 0.7 * (hash3(g).xy - 0.5)) * size;
}

// distance from q to the border of the shard of cell g (its Voronoi cell), negative outside it
float shardDist(vec2 q, vec2 g, float size) {
  vec2 sj = seed(g, size);
  float d = 1e9;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      if (x == 0 && y == 0) continue;
      vec2 sk = seed(g + vec2(float(x), float(y)), size);
      vec2 dir = sk - sj;
      d = min(d, dot(0.5 * (sj + sk) - q, dir) / length(dir));
    }
  }
  return d;
}

float ease(float t) {
  return t * t * (3.0 - 2.0 * t);
}

// how far a shard is out of place along its flight t: a quick burst, then a soft landing
float burst(float t) {
  float u = clamp(t / 0.4, 0.0, 1.0);
  float v = clamp((t - 0.4) / 0.6, 0.0, 1.0);
  return t < 0.4 ? 1.0 - (1.0 - u) * (1.0 - u) : 1.0 - ease(v);
}

vec4 transition(vec2 uv) {
  vec2 aspect = vec2(ratio, 1.0);
  vec2 x = (uv - 0.5) * aspect;
  float size = 1.0 / clamp(float(rows), 1.0, 8.0);
  float E = clamp(spread, 0.0, 0.5);
  float Z = clamp(depth, 0.0, 1.0);
  float p = clamp(progress, 0.0, 1.0);
  vec3 L = normalize(vec3(-0.45, 0.55, 1.0));
  vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
  vec3 eye = vec3(0.0, 0.0, EYE);
  vec3 dir = vec3(x, -EYE);
  // the cracks open as the image breaks and close as the shards lock back into place
  float act = smoothstep(0.0, START + DELAY, p) * (1.0 - smoothstep(START + FLIGHT, 1.0, p));

  // where this point roughly comes from, to find the shards that can cover it
  float b0 = burst(clamp((p - START - 0.5 * DELAY) / FLIGHT, 0.0, 1.0));
  vec2 x0 = x * (EYE - 0.75 * Z * b0) / EYE / (1.0 + E * b0);
  vec2 cell0 = floor(x0 / size);

  // the two nearest shards seen here: depth, image point, side (1 front), coverage, shading, rim
  float z1 = 1e9, z2 = 1e9;
  vec2 q1 = x, q2 = x;
  float f1 = 1.0, f2 = 1.0, m1 = 0.0, m2 = 0.0;
  float s1 = 1.0, s2 = 1.0, r1 = 0.0, r2 = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 g = cell0 + vec2(float(i), float(j));
      vec3 h = hash3(g + 17.0);
      float t = clamp((p - START - DELAY * h.x) / FLIGHT, 0.0, 1.0);
      float b = burst(t);
      // each shard turns over around its own axis at its own moment, while it is out of place
      float th = PI * ease(clamp((t - 0.1 - 0.48 * h.z) / 0.24, 0.0, 1.0));
      float ct = cos(th), st = sin(th);
      // and turns a little in the frame, back straight when it lands
      float phi = PI * h.y;
      float rz = 0.5 * (h.z - 0.5) * b;
      vec2 a0 = vec2(cos(phi), sin(phi));
      vec2 p0 = vec2(-a0.y, a0.x);
      vec3 a = vec3(cos(phi + rz), sin(phi + rz), 0.0);
      vec3 w = vec3(-a.y, a.x, 0.0) * ct + vec3(0.0, 0.0, st);
      vec2 c = seed(g, size);
      vec3 center = vec3(c * (1.0 + E * b), Z * b * (0.5 + 0.5 * h.x));
      vec3 nrm = cross(a, w);
      float den = dot(dir, nrm);
      if (abs(den) < 1e-6) continue;
      float lam = dot(center - eye, nrm) / den;
      if (lam <= 0.0) continue;
      vec3 hit = eye + lam * dir - center;
      float u = dot(hit, a), v = dot(hit, w);
      // the front carries the outgoing image, the back the incoming one, mirrored so that it lands in place;
      // the side seen is the one facing the eye, which swaps where the shard is seen edge-on
      float front = den < 0.0 ? 1.0 : -1.0;
      vec2 q = c + u * a0 + front * v * p0;
      // anti-aliased edges, scaled to the screen; at rest the shards overlap a little to hide their seams
      float k = EYE / (EYE - center.z);
      float e = shardDist(q, g, size) - CRACK * act;
      vec2 box = 0.5 * aspect - abs(q);
      e = min(e, min(box.x, box.y)) * k * mix(1.0, max(abs(ct), 0.2), min(b * 8.0, 1.0)) + 4.0 * EDGE * (1.0 - act);
      float m = clamp(e / (2.0 * EDGE) + 0.5, 0.0, 1.0);
      // at rest the shards lie at the same depth: the one that covers this point fully comes first
      float zk = lam - 0.001 * m;
      if (m <= 0.0 || zk >= z2) continue;
      // lit from the upper left, with a glint as a shard faces the light; unchanged at rest
      vec3 n = nrm * front;
      float lit = mix(0.45, 1.0, clamp(dot(n, L) / L.z, 0.0, 1.0));
      float glint = 0.2 * min(b * 4.0, 1.0) * pow(max(dot(n, H), 0.0), 24.0);
      // a pale rim on the broken edges while they fly, flashing as each shard locks into place
      float lock = sin(PI * clamp((t - 0.86) / 0.14, 0.0, 1.0));
      float rim = (0.3 * act * min(b * 4.0, 1.0) + 0.35 * lock) * (1.0 - smoothstep(0.0, 0.006, e));
      if (zk < z1) {
        z2 = z1; q2 = q1; f2 = f1; m2 = m1; s2 = s1; r2 = r1;
        z1 = zk; q1 = q; f1 = front; m1 = m; s1 = lit + glint; r1 = rim;
      } else {
        z2 = zk; q2 = q; f2 = front; m2 = m; s2 = lit + glint; r2 = rim;
      }
    }
  }

  vec4 col = backColor;
  if (m2 > 0.0) {
    vec2 src = q2 / aspect + 0.5;
    vec4 img = f2 > 0.0 ? getFromColor(src) : getToColor(src);
    img.rgb = mix(min(img.rgb * s2, vec3(img.a)), vec3(img.a), r2);
    col = mix(col, img, m2);
  }
  if (m1 > 0.0) {
    vec2 src = q1 / aspect + 0.5;
    vec4 img = f1 > 0.0 ? getFromColor(src) : getToColor(src);
    img.rgb = mix(min(img.rgb * s1, vec3(img.a)), vec3(img.a), r1);
    col = mix(col, img, m1);
  }
  return col;
}
