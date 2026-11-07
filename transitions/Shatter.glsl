// Author: lbl
// License: MIT
// Description: The outgoing image cracks like a pane of glass from an impact point, then its shards break loose from the impact outward, tumbling in 3D and falling away with gravity to reveal the incoming image behind
// Tags: shatter, fragments, glass, 3d

// @param Impact point where the cracks start, from (0, 0) at the bottom left to (1, 1) at the top right
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(3, 8) Approximate number of rows of shards across the height of the frame
uniform float shards; // = 6.0
// @range(0.5, 3) Strength of the gravity: the shards fall faster, and break loose over a longer time
uniform float gravity; // = 1.0
// @param Random seed: another value gives other shards, tumbling another way
uniform float seed; // = 0.0

// distance from the camera to the pane, as a part of the frame's height
const float EYE = 2.5;
// how far the corners of the shards are moved from a regular grid, as a part of a cell
const float JITTER = 0.32;
// width of the anti-aliased edges, the crack lines and the bevels, as a part of the frame's height
const float EDGE = 0.0012;
const float CRACK_WIDTH = 0.0025;
const float BEVEL = 0.006;

vec3 hash32(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float cellSize() {
  return 1.0 / clamp(shards, 3.0, 8.0);
}

vec2 seedOffset() {
  return vec2(37.0, 17.0) * floor(seed);
}

// a corner of the cracks: the point p of a grid, moved at random
vec2 corner(vec2 p) {
  return (p + JITTER * (2.0 * hash32(p + seedOffset()).xy - 1.0)) * cellSize();
}

// signed distance from q to the line a -> b, positive on its left
float side(vec2 q, vec2 a, vec2 b) {
  vec2 d = b - a;
  return (d.x * (q.y - a.y) - d.y * (q.x - a.x)) / length(d);
}

// the cell c is cut into two triangular shards along one of its diagonals, picked at random
bool diagonalUp(vec2 c) {
  return hash32(c + seedOffset() + 0.5).z > 0.5;
}

// distance from q to the edges of the triangle p0 p1 p2 (counterclockwise), positive inside
float triangleDist(vec2 q, vec2 p0, vec2 p1, vec2 p2) {
  return min(min(side(q, p0, p1), side(q, p1, p2)), side(q, p2, p0));
}

// the shard that contains q on the unbroken pane: (its cell, its triangle, the distance from q to its nearest crack)
vec4 locate(vec2 q) {
  vec2 c = floor(q / cellSize());
  // the cells' sides are not straight: step to the neighbor cell when q is beyond one of them
  vec2 a, b, cc, d;
  for (int i = 0; i < 2; i++) {
    a = corner(c);
    b = corner(c + vec2(1.0, 0.0));
    cc = corner(c + 1.0);
    d = corner(c + vec2(0.0, 1.0));
    c.x += side(q, d, a) < 0.0 ? -1.0 : (side(q, b, cc) < 0.0 ? 1.0 : 0.0);
    a = corner(c);
    b = corner(c + vec2(1.0, 0.0));
    cc = corner(c + 1.0);
    d = corner(c + vec2(0.0, 1.0));
    c.y += side(q, a, b) < 0.0 ? -1.0 : (side(q, cc, d) < 0.0 ? 1.0 : 0.0);
  }
  a = corner(c);
  b = corner(c + vec2(1.0, 0.0));
  cc = corner(c + 1.0);
  d = corner(c + vec2(0.0, 1.0));
  bool up = diagonalUp(c);
  float d0 = up ? triangleDist(q, a, b, cc) : triangleDist(q, a, b, d);
  float d1 = up ? triangleDist(q, a, cc, d) : triangleDist(q, b, cc, d);
  return vec4(c, d1 > d0 ? 1.0 : 0.0, abs(max(d0, d1)));
}

// Rodrigues' rotation of v around the unit axis k
vec3 rotate(vec3 v, vec3 k, float angle) {
  float c = cos(angle), s = sin(angle);
  return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

vec2 impact() {
  return clamp(center, 0.0, 1.0) * vec2(ratio, 1.0);
}

// distance from the impact to the farthest corner of the frame
float reach() {
  vec2 c = impact();
  return length(max(c, vec2(ratio, 1.0) - c));
}

// how far below its center a shard must fall to leave the frame
float fallMargin() {
  return 0.1 + 1.5 * cellSize();
}

// the time a shard breaks loose: the nearer the impact the sooner, and late enough to fall out of the frame by the end
// (dn: its distance to the impact, as a part of the reach)
float releaseTime(vec2 mid, float dn, float h, float g, float margin) {
  float latest = max(0.98 - sqrt(2.0 * (mid.y + margin) / g), 0.04);
  return 0.04 + (latest - 0.04) * (0.8 * pow(dn, 0.8) + 0.2 * h);
}

// a flash at the impact, at the start
float flash(vec2 q) {
  float f = sin(3.141592653589793 * clamp(progress / 0.12, 0.0, 1.0));
  vec2 d = q - impact();
  return 0.6 * f * exp(-dot(d, d) / (0.004 + 0.02 * progress));
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float s = cellSize();
  vec2 a = vec2(uv.x * ratio, uv.y);
  vec3 eye = vec3(0.5 * ratio, 0.5, -EYE);
  vec3 ray = vec3(a, 0.0) - eye;
  vec3 light = normalize(vec3(-0.35, 0.55, -1.0));
  vec3 halfway = normalize(light - normalize(ray));
  float g = 12.0 * clamp(gravity, 0.5, 3.0);
  vec2 imp = impact();
  float rch = reach();
  float margin = fallMargin();
  // the cracks run from the impact to the farthest corner, before the last shards break loose
  float crackTime = clamp(0.6 * (0.94 - sqrt(2.0 * (1.0 + margin) / g)), 0.05, 0.22);

  // the part of the pane still in place, behind the loose shards
  vec4 pane = vec4(0.0);
  float paneDepth = 1e9;
  vec4 here = locate(a);
  vec2 hc = here.xy;
  vec2 ha = corner(hc), hb = corner(hc + vec2(1.0, 0.0)), hcc = corner(hc + 1.0), hd = corner(hc + vec2(0.0, 1.0));
  bool hup = diagonalUp(hc);
  vec2 hcenter = here.z < 0.5 ? (hup ? ha + hb + hcc : ha + hb + hd) : (hup ? ha + hcc + hd : hb + hcc + hd);
  vec3 hh = hash32(hc + vec2(0.31, 0.57) * (here.z + 1.0) + seedOffset());
  hcenter /= 3.0;
  if (progress < releaseTime(hcenter, clamp(length(hcenter - imp) / rch, 0.0, 1.0), hh.x, g, margin)) {
    vec4 col = getFromColor(uv);
    float crack = clamp((progress - crackTime * length(a - imp) / rch) / 0.03, 0.0, 1.0);
    // cracked shards settle at slightly different angles (no change while flat: dot(n, light) = -light.z)
    vec3 n = rotate(vec3(0.0, 0.0, -1.0), normalize(vec3(hh.yz - 0.5, 0.0) + 1e-4), 0.06 * crack * (hh.x - 0.5));
    col.rgb *= 1.0 + 1.2 * (dot(n, light) + light.z);
    col.rgb += crack * 0.35 * pow(max(dot(n, halfway), 0.0), 400.0) * col.a;
    float line = crack * (1.0 - smoothstep(0.0, CRACK_WIDTH, here.w));
    col.rgb = mix(col.rgb, vec3(0.95, 0.98, 1.0) * col.a, 0.85 * line);
    pane = col;
    paneDepth = 1.0;
  }

  // the two nearest loose shards: depth along the ray, color, coverage
  float t1 = 1e9, t2 = 1e9;
  vec4 c1 = vec4(0.0), c2 = vec4(0.0);
  float a1 = 0.0, a2 = 0.0;
  float shadow = 0.0;

  // the shards that broke loose, searched in the cells around and above the pixel since they fall,
  // looking a bit toward the impact and the middle since they drift away and grow toward the camera
  vec2 look = a - 0.06 * progress * (a - imp) / rch - (a - eye.xy) * 0.06 * progress;
  vec2 g0 = floor(look / s) - 1.0;
  float rows = ceil(1.0 / s);
  for (int ri = 0; ri < 11; ri++) {
    float j = g0.y + float(ri);
    if (j > rows) break;
    if (j < -1.0) continue;
    for (int ci = 0; ci < 3; ci++) {
      vec2 c = vec2(g0.x + float(ci), j);
      vec2 ca = corner(c), cb = corner(c + vec2(1.0, 0.0)), ccc = corner(c + 1.0), cd = corner(c + vec2(0.0, 1.0));
      bool up = diagonalUp(c);
      for (int k = 0; k < 2; k++) {
        // the corners of the triangle k of the cell, counterclockwise
        vec2 p0 = (k == 1 && !up) ? cb : ca;
        vec2 p1 = k == 0 ? cb : ccc;
        vec2 p2 = (k == 0 && up) ? ccc : cd;
        vec2 mid = (p0 + p1 + p2) / 3.0;
        vec3 h1 = hash32(c + vec2(0.31, 0.57) * float(k + 1) + seedOffset());
        vec2 away = mid - imp;
        float dist = length(away);
        float dn = clamp(dist / rch, 0.0, 1.0);
        float e = progress - releaseTime(mid, dn, h1.x, g, margin);
        if (e <= 0.0) continue;
        vec3 h2 = hash32(c + vec2(0.73, 0.19) * float(k + 1) + seedOffset());
        // pushed away from the impact and toward the camera, spinning around a random axis, falling
        float near = 1.0 - dn;
        vec3 vel = vec3(away / max(dist, 1e-3) * (0.03 + 0.08 * h1.y) * (0.4 + near), -(0.05 + 0.2 * near * h1.z));
        vec3 pos = vec3(mid, 0.0) + vel * e - vec3(0.0, 0.5 * g * e * e, 0.0);
        // already out of the frame
        if (pos.y + 1.5 * s < -0.05) continue;
        vec3 axis = normalize(vec3(h2.x - 0.5, h2.y - 0.5, 0.3 * (h2.z - 0.5)) + 1e-4);
        float angle = (3.0 + 5.0 * h2.z) * (h2.x < 0.5 ? -1.0 : 1.0) * e;
        vec3 n = rotate(vec3(0.0, 0.0, -1.0), axis, angle);
        float rel = smoothstep(0.0, 0.04, e);

        // the camera ray, hidden behind the pane still in place
        float den = dot(ray, n);
        float t = dot(pos - eye, n) / (abs(den) > 1e-4 ? den : 1e-4);
        vec2 q = mid + rotate(eye + t * ray - pos, axis, -angle).xy;
        float border = min(min(q.x, ratio - q.x), min(q.y, 1.0 - q.y));
        float inside = triangleDist(q, p0, p1, p2);
        float ed = min(inside, border);
        if (t > 0.0 && t < t2 && t < paneDepth && ed > 0.0) {
          vec3 nf = den > 0.0 ? -n : n;
          vec4 col = getFromColor(vec2(q.x / ratio, q.y));
          col.rgb *= mix(1.0, clamp(dot(nf, light) / -light.z, 0.45, 1.1), rel);
          float glint = max(dot(nf, halfway), 0.0);
          col.rgb += rel * 0.3 * pow(glint, 60.0) * col.a;
          // the crack line it carried turns into a bright bevel
          float line = 0.85 * (1.0 - smoothstep(0.0, CRACK_WIDTH, inside)) * (1.0 - rel);
          float bevel = 0.8 * rel * (1.0 - smoothstep(0.0, BEVEL, ed)) * (0.3 + 0.7 * pow(glint, 6.0));
          col.rgb = mix(col.rgb, vec3(0.92, 0.97, 0.97) * col.a, max(line, bevel));
          float cover = mix(1.0, smoothstep(0.0, 2.0 * EDGE, ed), rel);
          if (t < t1) {
            t2 = t1; c2 = c1; a2 = a1;
            t1 = t; c1 = col; a1 = cover;
          } else {
            t2 = t; c2 = col; a2 = cover;
          }
        }

        // the shadow on the pane and on the incoming image behind
        float lden = dot(light, n);
        float ts = dot(pos - vec3(a, 0.0), n) / (abs(lden) > 1e-4 ? lden : 1e-4);
        vec2 qs = mid + rotate(vec3(a, 0.0) + ts * light - pos, axis, -angle).xy;
        float eds = min(triangleDist(qs, p0, p1, p2), min(min(qs.x, ratio - qs.x), min(qs.y, 1.0 - qs.y)));
        if (ts > 0.0 && eds > 0.0) {
          shadow = max(shadow, rel * smoothstep(0.0, 0.004 + 0.08 * ts, eds) * 0.45 * (1.0 - smoothstep(0.1, 0.9, ts)));
        }
      }
    }
  }

  // the incoming image behind, then the pane still in place, then the loose shards in front
  vec4 back = getToColor(uv);
  back.rgb *= 1.0 - shadow;
  pane.rgb *= 1.0 - shadow;
  if (paneDepth == 1.0) back = pane;
  vec4 color = c1 * a1 + c2 * min(a2, 1.0 - a1) + back * max(1.0 - a1 - a2, 0.0);
  color.rgb += flash(a) * color.a;
  return color;
}
