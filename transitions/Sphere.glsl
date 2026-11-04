// Author: gre
// License: MIT
// Description: The outgoing image wraps itself onto a shaded ball that shrinks and rolls away, revealing the incoming image under its shadow
// Tags: 3d, sphere, roll, wrap, shape

// @param Direction the ball rolls away toward
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0.1, 0.5) Radius of the ball once wrapped, relative to the shorter side of the frame
uniform float size; // = 0.3
// @range(0, 1) Strength of the light and shading on the ball
uniform float shading; // = 0.6
// @range(0, 1) Darkness of the soft shadow the ball casts on the incoming image
uniform float shadow; // = 0.5

const float PI = 3.14159265;
// half width of the antialiased ball edge, in frame heights
const float AA = 0.0015;
// toward the light, from the top left
const vec3 LIGHT = vec3(-0.5, 0.6, 1.0) / 1.2689;

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  vec4 b = getToColor(uv);
  if (progress >= 1.0) return b;

  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 side = vec2(-dir.y, dir.x);
  // measured in square pixels, so the ball is round
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float shorter = min(ratio, 1.0);
  float r0 = clamp(size, 0.1, 0.5) * shorter;

  // the image curves into a ball (infinite radius: exactly flat at the start), then the
  // ball shrinks while rolling away until it and its shadow have left the frame
  float w = clamp(progress / 0.45, 0.0, 1.0);
  w = 1.0 - (1.0 - w) * (1.0 - w);
  float away = smoothstep(0.3, 1.0, progress);
  away *= away;
  float wrapped = r0 / max(w, 1e-4);
  float radius = wrapped * mix(1.0, 0.5, away);
  // the image is pulled tighter as it wraps, so that it ends up covering the whole ball
  // (its shortest half extent reaches around to the back)
  float tight = mix(1.0, min(1.0, 0.48 * shorter / (PI * r0)), w * w);
  float paper = radius * tight;
  // half extent of the frame along the direction
  float e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  // far enough that the ball (0.5 * r0 by then) and its shadow (within 0.9 * r0 of it) have left
  float full = e + 1.1 * r0 + 2.0 * AA;
  float travel = away * full;
  vec2 center = dir * travel;
  // rolling without slipping: the integral of dtravel / radius while the radius shrinks
  float angle = -2.0 * full * log(1.0 - 0.5 * away) / wrapped;

  vec2 d = p - center;
  float r = length(d);

  // soft shadow on the incoming image, below and to the right of the ball (light from the top left)
  vec2 sd = d - vec2(0.25, -0.3) * radius * w;
  float sh = shadow * w * (1.0 - smoothstep(0.6 * radius, 1.4 * radius, length(sd)));
  vec4 bg = vec4(b.rgb * b.a * (1.0 - sh), b.a);

  vec4 ball = vec4(0.0);
  float cover = 1.0 - smoothstep(radius - AA, radius + AA, r);
  if (cover > 0.0) {
    // normal of the visible point of the ball (no squared radius, which overflows when it is huge)
    vec2 nd = d / radius;
    vec3 n = vec3(nd, sqrt(max(1.0 - dot(nd, nd), 0.0)));
    // undo the roll: rotate around the axis across the direction
    float u = dot(n.xy, dir);
    float s = dot(n.xy, side);
    float cu = cos(angle), su = sin(angle);
    vec3 q = vec3(u * cu - n.z * su, s, u * su + n.z * cu);
    // the image is wrapped around the ball from its front point, distances kept along the surface
    float lq = length(q.xy);
    float arc = atan(lq, q.z) * paper;
    vec2 img = lq > 0.0 ? (q.x * dir + q.y * side) / lq * arc : vec2(0.0);
    vec2 iuv = img / vec2(ratio, 1.0) + 0.5;
    // distance to the edge of the image, antialiased like the ball's outline
    vec2 edge = min(iuv, 1.0 - iuv) * vec2(ratio, 1.0);
    float inside = cover * smoothstep(-AA, AA, min(edge.x, edge.y));
    if (inside > 0.0) {
      vec4 c = getFromColor(clamp(iuv, 0.0, 1.0));
      float diff = max(dot(n, LIGHT), 0.0);
      float spec = pow(max(reflect(-LIGHT, n).z, 0.0), 24.0);
      float k = shading * w;
      vec3 lit = c.rgb * mix(1.0, 0.25 + 0.85 * diff, k) + 0.35 * k * spec;
      ball = vec4(clamp(lit, 0.0, 1.0) * c.a, c.a) * inside;
    }
  }

  // the ball over the incoming image, premultiplied so transparent images do not bleed their color
  vec4 c = ball + bg * (1.0 - ball.a);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
