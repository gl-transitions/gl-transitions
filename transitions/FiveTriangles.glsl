// Author: gre
// License: MIT
// Description: The outgoing image breaks into tiny triangles; in each group of five the middle one grows over the other four, then five of those become one, and so on at ever new angles, up to a few huge flat triangles; they take the incoming image's colors and each rolls open into five smaller ones until they are the incoming image
// Tags: triangles, pinwheel, flat, geometric, mosaic, abstract

float cross2(vec2 a, vec2 b) {
  return a.x * b.y - a.y * b.x;
}

// signed distance to the sides of a tile of short leg k (negative inside); every tile has legs k and 2k
float tri(vec2 p, vec2 r, vec2 l, vec2 s, float k) {
  vec3 d = vec3(cross2(l - r, p - r) * 0.5, cross2(s - l, p - l) * 0.4472136, cross2(r - s, p - s)) / k;
  d *= -sign(cross2(l - r, s - r));
  return max(d.x, max(d.y, d.z));
}

bool inside(vec2 p, vec2 r, vec2 l, vec2 s) {
  vec3 d = vec3(cross2(l - r, p - r), cross2(s - l, p - l), cross2(r - s, p - s)) * cross2(l - r, s - r);
  return min(d.x, min(d.y, d.z)) >= 0.0;
}

float hash(vec2 p) {
  vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 tile(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  float big = max(ratio, 1.0);
  vec2 p = (uv - 0.5) * asp / big;
  float ang = 0.5;
  p = mat2(cos(ang), sin(ang), -sin(ang), cos(ang)) * p;
  // a right triangle with legs 4 and 2 (r the right angle) that covers the frame
  vec2 r = vec2(-0.9, -0.75), l = r + vec2(4.0, 0.0), s = r + vec2(0.0, 2.0);
  float size = 2.0;
  vec2 q = vec2(0.0);
  // the path of the descent, child by child, names the tile for its timing
  float id = 0.0;
  bool late = false;
  for (int i = 0; i < 8; i++) {
    float f = float(i);
    // the subdivision's fixed point in this tile, so a merged tile keeps the color of its middle child
    q = 0.375 * r + 0.375 * l + 0.25 * s;
    float h = hash(vec2(id, f));
    vec2 H = mix(s, l, 0.2);
    vec2 a = 0.5 * (H + l), b = 0.5 * (H + r), c = 0.5 * (l + r);
    float off = tri(p, c, b, a, size * 0.4472136);
    if (i == 2) {
      late = off < size * (1.3 * smoothstep(0.0, 0.16, progress - 0.38 - 0.12 * h) - 0.2);
    }
    float lev = 7.0 - f;
    if (!late && i > 1) {
      float m = smoothstep(0.0, 1.0, (progress - 0.02 - 0.062 * lev - 0.05 * h) / 0.07);
      if (off < size * (1.3 * m - 0.2)) break;
    }
    vec2 R = c, L = b, S = a;
    float child = 4.0;
    if (inside(p, H, r, s)) {
      R = H; L = r; S = s; child = 0.0;
    } else if (inside(p, H, a, b)) {
      R = H; L = a; S = b; child = 1.0;
    } else if (inside(p, a, l, c)) {
      R = a; L = l; S = c; child = 2.0;
    } else if (inside(p, b, c, r)) {
      R = b; L = c; S = r; child = 3.0;
    }
    r = R; l = L; s = S;
    id = id * 5.0 + child;
    size *= 0.4472136;
    if (late) {
      float m = smoothstep(0.0, 1.0, (progress - 0.92 + 0.062 * lev - 0.05 * h) / 0.08);
      // unrolled from its long side
      if (abs(cross2(s - l, p - l)) * 0.4472136 > 0.9 * size * size * m) break;
    }
  }
  q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * q;
  vec2 k = fold(q * big / asp + 0.5);
  vec4 c = late ? getToColor(k) : getFromColor(k);
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  vec2 e = 0.0004 * vec2(1.0 / ratio, 1.0);
  vec4 c = tile(uv + e * vec2(0.5, 1.0)) + tile(uv - e * vec2(0.5, 1.0));
  c = vec4(c.rgb / max(c.a, 1e-5), 0.5 * c.a);
  float u = 1.0 - abs(2.0 * progress - 1.0);
  return mix(progress < 0.5 ? getFromColor(uv) : getToColor(uv), c, smoothstep(0.0, 0.1, u));
}
