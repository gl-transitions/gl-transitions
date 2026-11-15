// Author: gre
// License: MIT
// Description: The image is cut into a mosaic of triangles that turn over in perspective in a wave spreading from a point, each one rolling away from it about one of its three axes, catching a glint of light and casting a soft shadow, and showing its part of the incoming image on its back
// Tags: triangles, tiles, flip, 3d, wave, geometric

// @range(2, 20, 1) Number of rows of triangles across the height of the frame
uniform int rows; // = 6
// @param Point the wave of flips spreads from (0,0 is the bottom left corner, 1,1 the top right one)
uniform vec2 center; // = vec2(0.0, 1.0)
// @range(0, 0.9) How long the wave takes to cross the frame, as a part of the transition: 0 turns every triangle at once
uniform float stagger; // = 0.75
// @range(0, 1) Strength of the light and shadows on the turning triangles and of the shade in the holes they leave
uniform float shading; // = 0.6

const float PI = 3.141592653589793;
const float SQRT3 = 1.7320508075688772;
// half width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0012;
// distance of the eye from the sheet, in triangle sides
const float EYE = 3.0;
// how high a turning triangle lifts off the sheet, in triangle sides
const float LIFT = 0.3;
// light from the upper left, in front of the frame
const vec3 LIGHT = vec3(-0.4, 0.45, 0.8);

// smooth start and landing, without lingering at either end
float easeInOut(float t) {
  return mix(t, t * t * (3.0 - 2.0 * t), 0.75);
}

// signed distance (positive inside) from p to an equilateral triangle centered on
// its centroid, with inradius r, pointing up (o = 1) or down (o = -1), measured on
// screen when the triangle is squeezed by k along b (turned about the axis a)
float triDistSqueezed(vec2 p, float r, float o, vec2 a, vec2 b, float k) {
  vec2 n0 = vec2(0.0, -o);
  vec2 n1 = vec2(0.5 * SQRT3, 0.5) * o;
  vec2 n2 = vec2(-0.5 * SQRT3, 0.5) * o;
  float d0 = (r - dot(p, n0)) * k / length(vec2(dot(n0, a) * k, dot(n0, b)));
  float d1 = (r - dot(p, n1)) * k / length(vec2(dot(n1, a) * k, dot(n1, b)));
  float d2 = (r - dot(p, n2)) * k / length(vec2(dot(n2, a) * k, dot(n2, b)));
  return min(d0, min(d1, d2));
}

float triDist(vec2 p, float r, float o) {
  return triDistSqueezed(p, r, o, vec2(1.0, 0.0), vec2(0.0, 1.0), 1.0);
}

// folds coordinates back into the frame, so no turning piece shows clamped borders
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

float aa(float d, float e) {
  return clamp(d / max(2.0 * e, 1e-6) + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec2 frame = vec2(ratio, 1.0);
  vec2 pos = uv * frame;
  float h = 1.0 / max(float(rows), 1.0);
  float side = 2.0 * h / SQRT3;
  float inradius = side / (2.0 * SQRT3);
  vec2 e1 = vec2(side, 0.0);
  vec2 e2 = vec2(0.5 * side, h);
  // skewed lattice coordinates: each cell holds an upward and a downward triangle
  float lv = pos.y / h;
  vec2 cell = floor(vec2(pos.x / side - 0.5 * lv, lv));
  float eye = EYE * side;

  vec2 origin = center * frame;
  vec2 farthest = max(origin, frame - origin);
  float reach = max(length(farthest), 1e-4);
  float st = clamp(stagger, 0.0, 0.9);
  float sh = clamp(shading, 0.0, 1.0);
  vec3 l = normalize(LIGHT);
  vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
  // the median axes of the triangles, the same for both orientations
  vec2 a0 = vec2(0.0, 1.0);
  vec2 a1 = vec2(0.5 * SQRT3, 0.5);
  vec2 a2 = vec2(-0.5 * SQRT3, 0.5);

  // the triangles lying flat, weighted by side, and the holes of the turning ones
  float wFrom = 0.0;
  float wTo = 0.0;
  float hole = 0.0;
  float shadow = 0.0;
  // the two nearest turning triangles covering this point
  vec4 c1 = vec4(0.0);
  vec4 c2 = vec4(0.0);
  float m1 = 0.0;
  float m2 = 0.0;
  float z1 = -1e9;
  float z2 = -1e9;
  vec4 col;

  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      for (int k = 0; k < 2; k++) {
        vec2 nc = cell + vec2(float(i), float(j));
        float o = k == 0 ? 1.0 : -1.0;
        vec2 base = nc.x * e1 + nc.y * e2;
        vec2 ctr = base + (k == 0 ? 1.0 : 2.0) * (e1 + e2) / 3.0;
        vec2 q = pos - ctr;

        vec2 toward = ctr - origin;
        float dist = length(toward);
        vec2 dir = dist > 1e-5 ? toward / dist : vec2(1.0, 0.0);
        float delay = clamp(dist / reach, 0.0, 1.0);
        float t = clamp((progress - delay * st) / (1.0 - st), 0.0, 1.0);

        if (t <= 0.0 || t >= 1.0) {
          float m = aa(triDist(q, inradius, o), EDGE);
          if (t <= 0.0) wFrom += m;
          else wTo += m;
          continue;
        }

        // turn about the median of the triangle that lies most across the wave,
        // so the triangle rolls over away from the origin of the wave
        vec2 a = a0;
        if (abs(dot(a1, dir)) < abs(dot(a, dir))) a = a1;
        if (abs(dot(a2, dir)) < abs(dot(a, dir))) a = a2;
        vec2 b = vec2(-a.y, a.x);
        if (dot(b, dir) > 0.0) b = -b;

        float ang = PI * easeInOut(t);
        float ca = cos(ang);
        float sa = sin(ang);
        float lift = LIFT * side * sa;

        // the hole it leaves shows the incoming image in its shade, the outgoing one
        // right as it takes off so its edges stay seamless
        float mh = aa(triDist(q, inradius, o), EDGE);
        float k2 = smoothstep(0.0, 0.2, t);
        wFrom += mh * (1.0 - k2);
        wTo += mh * k2;
        hole = max(hole, mh * sa);
        // soft shadow under the turning triangle, squeezed like it and pushed away from the light
        vec2 sq = q + LIGHT.xy / LIGHT.z * lift;
        float sk = 0.3 + 0.7 * abs(ca);
        vec2 sp = dot(sq, a) * a + dot(sq, b) / sk * b;
        float sd = triDistSqueezed(sp, inradius, o, a, b, sk);
        float blur = 0.004 + 0.3 * lift;
        shadow = max(shadow, 0.5 * sa * (1.0 - smoothstep(-blur, blur, -sd)));

        // ray from the eye above the ctr through this point to the turned plane,
        // spanned by a and (b cos, sin) and lifted by lift
        float qb = dot(q, b);
        float den = eye * ca + sa * qb;
        if (abs(den) < 1e-6) continue;
        float s = (eye - lift) * ca / den;
        if (s <= 0.0) continue;
        float hz = eye * (1.0 - s);
        float alpha = s * dot(q, a);
        float beta = s * qb * ca + (hz - lift) * sa;
        vec2 lp = alpha * a + beta * b;
        float d = triDistSqueezed(lp, inradius, o, a, b, max(abs(ca), 1e-3)) / s;
        float m = aa(d, EDGE);
        if (m <= 0.0) continue;

        // the front shows the outgoing image, the back the incoming one seen from behind
        bool front = ca > 0.0;
        if (front) {
          col = getFromColor(mirror((ctr + lp) / frame));
        } else {
          col = getToColor(mirror((ctr + alpha * a - beta * b) / frame));
        }
        vec3 n = vec3(-sa * b, ca) * (front ? 1.0 : -1.0);
        float lit = dot(n, l) / l.z;
        col.rgb *= 1.0 - sh * (1.0 - clamp(lit, 0.0, 1.0)) * 0.65 + sh * 0.15 * max(lit - 1.0, 0.0);
        float spec = pow(max(dot(n, hv), 0.0), 60.0);
        col.rgb += sh * sa * (0.45 * spec + 0.15 * (1.0 - smoothstep(0.0, 3.0 * EDGE, d))) * col.a;

        if (hz > z1) {
          c2 = c1; m2 = m1; z2 = z1;
          c1 = col; m1 = m; z1 = hz;
        } else if (hz > z2) {
          c2 = col; m2 = m; z2 = hz;
        }
      }
    }
  }

  vec4 color = mix(getFromColor(uv), getToColor(uv), wTo / max(wFrom + wTo, 1e-6));
  color.rgb *= 1.0 - sh * clamp(max(shadow, 0.8 * hole), 0.0, 1.0);
  color = mix(color, c2, m2);
  color = mix(color, c1, m1);
  return color;
}
