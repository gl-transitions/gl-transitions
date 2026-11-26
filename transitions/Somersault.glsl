// Author: gre
// License: MIT
// Description: A tiny square of the incoming picture pops up in the outgoing one, then flips over its corner again and again, each flip landing a bigger square beside the last, so the squares spiral out like a Fibonacci tiling until the last huge flip covers the frame
// Tags: squares, fibonacci, spiral, geometry, flip, reveal

// @range(0, 1) Opacity of the guide lines along the squares' edges
uniform float lines; // = 0.85
// @color Color of the guide lines
uniform vec4 lineColor; // = vec4(1.0, 1.0, 1.0, 1.0)
// @range(0, 1) How much the moving square lights up while it turns
uniform float glow; // = 0.25

const float AA = 0.02;

float box(vec2 p, vec4 r) {
  vec2 a = min(p - r.xz, r.yw - p);
  return min(a.x, a.y);
}

float ease(float t) {
  t = clamp(t, 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// Fibonacci squares 1,1,2,3,5,8,13 spiral into a 13x21 rectangle: in step k, square k-1
// turns a quarter turn around corner(k) while it grows into square k
vec2 corner(int k) {
  return k == 1 ? vec2(1.0, 0.0) : k == 2 ? vec2(2.0, 1.0) : k == 3 ? vec2(0.0, 3.0) : k == 4 ? vec2(-3.0, 0.0) : k == 5 ? vec2(2.0, -5.0) : vec2(10.0, 3.0);
}

vec2 quadrant(int k) {
  return k == 1 ? vec2(-1.0, 1.0) : k == 2 ? vec2(-1.0, -1.0) : k == 3 ? vec2(1.0, -1.0) : k == 4 ? vec2(1.0, 1.0) : k == 5 ? vec2(-1.0, 1.0) : vec2(-1.0, -1.0);
}

// rectangle tiled before step k, as (x0, x1, y0, y1)
vec4 tiled(int k) {
  return k == 1 ? vec4(0.0, 1.0, 0.0, 1.0) : k == 2 ? vec4(0.0, 2.0, 0.0, 1.0) : k == 3 ? vec4(0.0, 2.0, 0.0, 3.0) : k == 4 ? vec4(-3.0, 2.0, 0.0, 3.0) : k == 5 ? vec4(-3.0, 2.0, -5.0, 3.0) : vec4(-3.0, 10.0, -5.0, 3.0);
}

float fib(int k) {
  return k < 2 ? 1.0 : k == 2 ? 2.0 : k == 3 ? 3.0 : k == 4 ? 5.0 : k == 5 ? 8.0 : 13.0;
}

vec4 transition(vec2 uv) {
  // the 13x21 rectangle covers the frame, its long side along the frame's long side
  bool wide = ratio >= 1.0;
  float aspect = wide ? ratio : 1.0 / ratio;
  vec2 f = wide ? uv.yx : uv;
  float span = min(21.0, 13.0 * aspect);
  vec2 L = vec2(3.5, 5.5) + (f - 0.5) * vec2(span / aspect, span);
  // tumble durations grow with the squares (0.4 for the first pop): they sum to 5.84
  float T = progress * 5.84;
  float t0 = clamp(T / 0.4, 0.0, 1.0);
  float s0 = ease(t0) * (0.5 + AA) - AA;
  float d0 = box(L, vec4(0.5 - s0, 0.5 + s0, 0.5 - s0, 0.5 + s0));
  float inside = smoothstep(-AA, AA, d0);
  float edge = clamp(s0 * 4.0, 0.0, 1.0) * (1.0 - smoothstep(0.0, AA * 1.5, abs(d0)));
  float moving = (1.0 - t0) * step(0.0, d0);
  float start = 0.4;
  for (int k = 1; k < 7; k++) {
    float dur = 0.3 + 0.04 * float(k * k);
    float t = (T - start) / dur;
    start += dur;
    if (t > 0.0) {
      float dl = box(L, tiled(k));
      inside = max(inside, smoothstep(-2.0 * AA, 0.0, dl));
      edge = max(edge, 1.0 - smoothstep(0.0, AA * 1.5, abs(dl)));
      float e = ease(t);
      float a = -1.5707963 * e;
      vec2 d = L - corner(k);
      d = vec2(cos(a) * d.x + sin(a) * d.y, -sin(a) * d.x + cos(a) * d.y) * quadrant(k);
      float s = mix(fib(k - 1), fib(k), e);
      float dm = box(d, vec4(0.0, s, 0.0, s));
      inside = max(inside, smoothstep(-2.0 * AA, 0.0, dm));
      edge = max(edge, 1.0 - smoothstep(0.0, AA * 1.5, abs(dm)));
      moving = max(moving, 4.0 * t * (1.0 - t) * step(0.0, dm));
    }
  }
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  b.rgb = mix(b.rgb, vec3(1.0), glow * moving * 0.6);
  vec4 c = mix(a, b, inside);
  float fade = min(1.0, (1.0 - progress) * 5.0);
  return mix(c, lineColor, lines * edge * fade);
}
