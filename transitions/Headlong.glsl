// Author: gre
// License: MIT
// Description: The outgoing image turns into flat dark shapes on an empty page and the view plunges headlong into its emptiest spot, the shapes rushing out past; in the void a tiny silhouette of the incoming image appears, grows all the way and fills in with its colors
// Tags: zoom, silhouette, flat, poster, dive, graphic
// Preview: 0.5

// @range(3, 8) How deep the dive goes
uniform float depth; // = 5.0
// @range(0, 2.5) How vivid the flat colors are
uniform float vivid; // = 1.5

const int SPOTS = 9;
const int TAPS = 5;

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

float ease(float a, float b, float x) {
  x = clamp((x - a) / (b - a), 0.0, 1.0);
  return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

// wavers along the frame, to round off the masses it cuts
float rim(vec2 q) {
  vec2 d = abs(2.0 * q - 1.0);
  d *= d * d;
  d *= d;
  float n = sin(q.x * 11.0 + 2.0 * sin(q.y * 7.0)) + sin(q.y * 13.0 - 1.5 * sin(q.x * 9.0));
  return smoothstep(0.35, 0.95, d.x + d.y + 0.09 * n);
}

vec3 inkOf(vec4 sum) {
  vec3 c = sum.rgb / sum.a;
  return clamp(0.8 * luma(c) + vivid * (c - luma(c)), 0.0, 1.0);
}

vec3 pageOf(vec4 sum) {
  vec3 c = sum.rgb / sum.a;
  return clamp(0.3 + 0.65 * luma(c) + 0.87 * vivid * (c - luma(c)), 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec4 da = vec4(0.0), db = da, la = da, lb = da;
  vec3 ga = vec3(0.5, 0.5, 1.0) * 1e-4, gb = ga;
  vec4 stats = vec4(0.0);
  for (int i = 0; i < SPOTS; i++) {
    vec2 q = fract(vec2(0.754878, 0.569840) * float(i) + 0.4);
    vec4 ca = getFromColor(q);
    vec4 cb = getToColor(q);
    float ya = luma(ca.rgb), yb = luma(cb.rgb);
    stats += vec4(ya * ca.a, ca.a, yb * cb.a, cb.a);
    vec2 d = exp(-8.0 * vec2(ya, yb)) * vec2(ca.a, cb.a);
    vec2 l = exp(8.0 * vec2(ya, yb)) * vec2(ca.a, cb.a);
    da += vec4(ca.rgb, 1.0) * d.x;
    db += vec4(cb.rgb, 1.0) * d.y;
    la += vec4(ca.rgb, 1.0) * l.x;
    lb += vec4(cb.rgb, 1.0) * l.y;
    ga += vec3(q, 1.0) * l.x;
    gb += vec3(q, 1.0) * l.y;
  }
  vec2 oa = ga.xy / ga.z, ob = gb.xy / gb.z;
  vec2 focus = mix(ob, vec2(0.5), 0.6);
  float za = exp(-depth * progress * progress * (3.0 - 2.0 * progress));
  float zb = exp(3.2 * (1.0 - ease(-0.2, 0.9, progress)));
  vec2 pa = oa + (uv - oa) * za;
  vec2 pb = focus + (uv - mix(mix(oa, vec2(0.5), 0.35), focus, smoothstep(0.1, 0.9, progress))) * zb;

  vec4 ca = getFromColor(pa);
  vec4 cb = getToColor(fold(pb));
  // the color to fall back on where the spots of an image are all transparent
  vec4 own = 1e-6 * vec4((ca.rgb * ca.a + cb.rgb * cb.a) / max(ca.a + cb.a, 1e-4), 1.0);
  da += own;
  db += own;
  la += own;
  lb += own;
  stats += vec2(luma(own.rgb), 1e-6).xyxy;
  vec2 mean = stats.xz / stats.yw;

  float soft = 0.02 * smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  vec4 y = vec4(1e-5);
  for (int i = 0; i < TAPS; i++) {
    float n = 1.25664 * float(i);
    vec2 o = soft * vec2(cos(n), sin(n)) / vec2(ratio, 1.0);
    vec4 ta = getFromColor(fold(pa + o));
    vec4 tb = getToColor(fold(pb + o));
    y += vec4(luma(ta.rgb) * ta.a, ta.a, luma(tb.rgb) * tb.a, tb.a);
  }
  y.xz = y.xz / y.yw - mean;

  float wa = 0.03 + 0.03 * smoothstep(0.2, 0.5, progress);
  float inkA = 1.0 - smoothstep(-wa, wa, y.x + 0.5 * ease(0.35, 0.62, progress));
  float edge = 1.0 - smoothstep(0.76, 0.92, progress);
  vec2 d = abs(pb - 0.5);
  float outside = 0.5 * rim(pb) + 4.0 * smoothstep(0.5, 0.52, max(d.x, d.y));
  float inkB = 1.0 - smoothstep(-0.02, 0.02, y.z + outside * edge + ease(0.4, 0.2, progress));
  vec3 col = mix(pageOf(la), pageOf(lb), smoothstep(0.35, 0.65, progress));
  col = mix(col, inkOf(da), inkA);
  col = mix(col, inkOf(db), inkB);

  bool late = progress > 0.5;
  float flatness = smoothstep(0.02, 0.2, progress) * (1.0 - smoothstep(0.82, 0.99, progress));
  return vec4(mix(late ? cb.rgb : ca.rgb, col, flatness), mix(ca.a, cb.a, smoothstep(0.35, 0.65, progress)));
}
