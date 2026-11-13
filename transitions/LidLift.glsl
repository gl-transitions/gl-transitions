// Author: gre
// License: MIT
// Description: Seen from above, the outgoing image is the lid of a box: the camera pulls back to show the box on a table, the lid is lifted by one side and carried off with its rim showing, uncovering the incoming image at the bottom of the box between shaded walls, and the camera moves down into the box
// Tags: 3d, box, lid, perspective, reveal, shadow, directional

// @range(0, 360) Direction the lid is carried off to, in degrees (0 is toward the right, 90 toward the top)
uniform float angle; // = 20.0
// @range(0.1, 0.8) Depth of the box, as a part of the frame's height
uniform float depth; // = 0.45
// @range(0, 1.5) How far the camera pulls back
uniform float zoom; // = 0.6
// @range(0, 60) How much the lid tilts as it is lifted by one side, in degrees
uniform float tilt; // = 30.0
// @range(-0.25, 0.25) How much the lid turns as it is carried off, in turns
uniform float turn; // = 0.04
// @range(0, 1) Darkness of the box walls, of the lid's rim and of the shadows
uniform float shading; // = 0.6
// @color Color of the table around the box
uniform vec4 background; // = vec4(0.16, 0.15, 0.14, 1.0)
// @color Color of the inside walls of the box
uniform vec4 wallColor; // = vec4(0.88, 0.85, 0.8, 1.0)

const float PI = 3.141592653589793;
// distance from the camera to the image when it fills the frame
const float FOCAL = 2.2;
// height of the lid's rim, in frame heights
const float RIM = 0.1;
// thickness of the box's walls, as a part of the box's size
const float WALL = 0.025;
const vec3 LIGHT = vec3(-0.45, 0.55, 0.75);

vec4 premultiply(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec2 toUV(vec2 q, vec2 r) {
  return clamp(0.5 + 0.5 * q / r, 0.0, 1.0);
}

// signed distance to the rectangle of half size r
float rectDist(vec2 q, vec2 r) {
  vec2 e = abs(q) - r;
  return length(max(e, 0.0)) + min(max(e.x, e.y), 0.0);
}

mat3 rotAxis(vec3 k, float a) {
  float c = cos(a), s = sin(a), t = 1.0 - c;
  return mat3(
    t * k.x * k.x + c, t * k.x * k.y + s * k.z, t * k.x * k.z - s * k.y,
    t * k.x * k.y - s * k.z, t * k.y * k.y + c, t * k.y * k.z + s * k.x,
    t * k.x * k.z + s * k.y, t * k.y * k.z - s * k.x, t * k.z * k.z + c);
}

mat3 transposed(mat3 m) {
  return mat3(m[0].x, m[1].x, m[2].x, m[0].y, m[1].y, m[2].y, m[0].z, m[1].z, m[2].z);
}

// soft shadow of the lid, seen from the point o toward the light d, in the lid's frame
float lidShadow(vec3 o, vec3 d, vec2 R) {
  if (d.z <= 0.0 || o.z >= 0.0) return 0.0;
  float t = -o.z / d.z;
  return clamp(-rectDist(o.xy + t * d.xy, R) / (0.01 + 0.12 * t) + 0.5, 0.0, 1.0);
}

// soft shadow of the box's walls on a point w inside it: the light is blocked
// when its ray leaves the inner rectangle before reaching the top of the walls
float wallShadow(vec3 w, vec3 L, vec2 Ri) {
  float s = -w.z / L.z;
  return clamp(rectDist(w.xy + s * L.xy, Ri) / (0.004 + 0.05 * s) + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float p = progress;
  float D = max(depth, 0.01);
  vec2 R = vec2(0.5 * ratio, 0.5);
  vec2 Ri = R * (1.0 - WALL);
  vec2 P = (uv - 0.5) * vec2(ratio, 1.0);
  vec3 L = normalize(LIGHT);

  // the camera pulls back, then moves down into the box until its floor fills the frame
  float pull = smoothstep(0.0, 0.36, p);
  float dive = smoothstep(0.5, 1.0, p);
  // eased on the inverse of the distance to the floor, so that the image grows at an even pace
  float G0 = FOCAL * (1.0 + zoom * pull) + D;
  float G1 = FOCAL * (1.0 - WALL);
  float G = 1.0 / mix(1.0 / G0, 1.0 / G1, dive) - D;
  vec3 E = vec3(0.0, 0.0, G);
  vec3 d = vec3(P, -FOCAL);
  // width of the antialiased edges per unit of ray length, kept to zero at both ends,
  // where the lid and then the floor line up with the frame's border
  float aa = max(0.0015 * min(1.0, 40.0 * min(pull, 1.0 - dive)), 1e-6);

  // the lid: lifted by its side away from the direction, pivoting on the other side, then raised and carried off
  float a = radians(angle);
  vec2 dir = vec2(cos(a), sin(a));
  float half_ = abs(dir.x) * R.x + abs(dir.y) * R.y;
  float lift = smoothstep(0.1, 0.42, p);
  float go = smoothstep(0.26, 0.8, p);
  float tl = radians(tilt) * lift * (1.0 - 0.6 * go);
  // far enough for the lid, however it is turned, to leave the widest view of the table
  float reach = (1.0 + zoom) * half_ + length(R) + 0.15;
  // the raised side always stays below the camera
  float h = min(0.55 * go + half_ * sin(tl) + RIM * lift, 0.85 * G - half_ * sin(tl));
  vec3 C = vec3(dir * reach * go, h);
  mat3 M = rotAxis(vec3(0.0, 0.0, 1.0), 2.0 * PI * turn * go) * rotAxis(vec3(-dir.y, dir.x, 0.0), tl);
  mat3 Mi = transposed(M);
  vec3 o = Mi * (E - C), dl = Mi * d;

  // the lid's top
  float tTop = 1e9;
  vec4 lid = vec4(0.0);
  if (dl.z < 0.0 && o.z > 0.0) {
    float t = -o.z / dl.z;
    vec2 q = o.xy + t * dl.xy;
    float m = clamp(-rectDist(q, R) / (aa * t) + 0.5, 0.0, 1.0);
    if (m > 0.0) {
      tTop = t;
      vec3 n = M * vec3(0.0, 0.0, 1.0);
      lid = premultiply(getFromColor(toUV(q, R))) * m;
      lid.rgb *= mix(1.0, min((0.5 + 0.5 * max(dot(n, L), 0.0)) / (0.5 + 0.5 * L.z), 1.0), shading);
    }
  }
  // the outer side of its rim nearest along the ray, where the top does not fully cover
  if (lid.a < 1.0) {
    float tRim = tTop;
    vec4 rim = vec4(0.0);
    for (int i = 0; i < 4; i++) {
      bool ax = i < 2;
      float sg = (i == 0 || i == 2) ? 1.0 : -1.0;
      float oc = ax ? o.x : o.y, dc = ax ? dl.x : dl.y, rc = ax ? R.x : R.y;
      // only the outer faces, seen from outside
      if (sg * dc >= 0.0) continue;
      float t = (sg * rc - oc) / dc;
      vec3 hp = o + t * dl;
      float other = ax ? hp.y : hp.x, ro = ax ? R.y : R.x;
      // the side is extended above the top, where only rays through the top's antialiased edge
      // reach it, so that no seam shows between the two
      float rm = clamp(min(ro - abs(other), hp.z + RIM) / (aa * t) + 0.5, 0.0, 1.0);
      if (t <= 0.0 || t >= tRim || rm <= 0.0 || hp.z > RIM) continue;
      tRim = t;
      // the outgoing image folds over the edge onto the rim
      float inset = sg * (rc + hp.z);
      vec2 edge = ax ? vec2(inset, hp.y) : vec2(hp.x, inset);
      vec3 n = M * (ax ? vec3(sg, 0.0, 0.0) : vec3(0.0, sg, 0.0));
      rim = premultiply(getFromColor(toUV(edge, R))) * rm;
      rim.rgb *= (1.0 - shading * (0.7 - 0.7 * max(dot(n, L), 0.0))) * (1.0 - 0.3 * shading * (-hp.z / RIM));
    }
    lid += rim * (1.0 - lid.a);
  }
  if (lid.a >= 1.0) return lid;

  // the box: its walls stand on the table (z = -D) up to their top (z = 0)
  float tr = G / FOCAL;
  vec2 top = tr * P;
  float inBox = clamp(-rectDist(top, R) / (aa * tr) + 0.5, 0.0, 1.0);
  float tf = (G + D) / FOCAL;
  vec2 F = tf * P;
  vec4 col = vec4(0.0);
  vec3 W = vec3(F, -D);

  if (inBox > 0.0) {
    // inside: the floor, or the inner wall the ray meets first
    float onFloor = clamp(-rectDist(F, Ri) / (aa * tf) + 0.5, 0.0, 1.0);
    vec4 floorCol = premultiply(getToColor(toUV(F, Ri)));
    float m = max(abs(P.x) / Ri.x, abs(P.y) / Ri.y);
    float tw = 1.0 / max(m, 1e-4);
    vec3 Ww = vec3(tw * P, clamp(G - tw * FOCAL, -D, 0.0));
    bool sideX = abs(P.x) / Ri.x > abs(P.y) / Ri.y;
    vec3 nw = sideX ? vec3(-sign(P.x), 0.0, 0.0) : vec3(0.0, -sign(P.y), 0.0);
    vec4 wall = premultiply(wallColor);
    float lit = 0.45 + 0.55 * max(dot(nw, L), 0.0);
    // walls darken toward the floor, and the floor toward the walls
    float wallAO = 1.0 - 0.45 * exp(-(Ww.z + D) / (0.12 * D + 0.02));
    wall.rgb *= mix(1.0, lit * wallAO, shading);
    wall.rgb *= 1.0 - 0.45 * shading * wallShadow(Ww, L, Ri);
    float floorAO = exp(-max(-rectDist(F, Ri), 0.0) / 0.05);
    float fs = 0.45 * floorAO + 0.45 * wallShadow(vec3(F, -D), L, Ri);
    floorCol.rgb *= 1.0 - shading * (1.0 - dive * dive) * min(fs, 0.8);
    vec4 inner = mix(wall, floorCol, onFloor);
    vec3 Wi = mix(Ww, vec3(F, -D), onFloor);

    // the top of the walls catches the light
    vec4 rimTop = premultiply(wallColor);
    rimTop.rgb *= mix(1.0, 0.75 + 0.25 * L.z, shading);
    float inOpen = clamp(-rectDist(top, Ri) / (aa * tr) + 0.5, 0.0, 1.0);
    col = mix(rimTop, inner, inOpen) * inBox;
    W = mix(W, mix(vec3(top, 0.0), Wi, inOpen), inBox);
  }
  if (inBox < 1.0) {
    // outside: the table, with the box's shadow away from the light,
    // the box's outline swept along the light: a hexagon
    vec4 table = premultiply(background);
    vec2 sl = L.xy / L.z * D;
    vec2 nl = normalize(vec2(-sl.y, sl.x));
    float hex = max(rectDist(F + 0.5 * sl, R + 0.5 * abs(sl)), abs(dot(F, nl)) - dot(R, abs(nl)));
    float boxSh = clamp(-hex / (0.01 + 0.06 * D) + 0.5, 0.0, 1.0);
    float contact = exp(-max(rectDist(F, R), 0.0) / 0.025);
    table.rgb *= 1.0 - shading * max(0.55 * boxSh, 0.7 * contact);
    col += table * (1.0 - inBox);
  }

  // the lid's shadow, toward the light
  // (it fades as the camera moves in, so that a lid carried toward the light leaves the floor clean)
  float sh = lidShadow(Mi * (W - C), Mi * L, R);
  col.rgb *= 1.0 - 0.6 * shading * sh * lift * (1.0 - dive);

  col = lid + col * (1.0 - lid.a);
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
