// Author: gre
// License: MIT
// Description: A line sweeps across the frame and stretches the outgoing image's pixels into long streaks behind it, then the streaks retract and reveal the incoming image
// Tags: smear, streaks, directional, chromatic

// @param Direction in which the line sweeps
uniform vec2 direction; // = vec2(1.0, 0.0)
// @range(0, 1) Amount of RGB split along the streaks
uniform float chroma; // = 0.5
// @range(0, 0.2) Softness of the line, as a part of the frame
uniform float softness; // = 0.03
// @range(0, 1) How much the streaks jitter, each row at its own length
uniform float jitter; // = 0.5

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

// smooth max with a compact support: exactly max(x, y) when they are k apart
float smax(float x, float y, float k) {
  float h = max(k - abs(x - y), 0.0) / k;
  return max(x, y) + h * h * k * 0.25;
}

// position s along the sweep (0 to 1 across the frame) to a frame coordinate
vec2 at(vec2 uv, float s0, float s, vec2 d, float ext) {
  return clamp(uv + d * (s - s0) * ext, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  vec2 d = normalize(direction + vec2(1e-6, 0.0));
  // ext: length of the frame along the sweep, in uv units
  float ext = abs(d.x) + abs(d.y);
  float s = 0.5 + dot(uv - 0.5, d) / ext;
  // rows across the streaks (about one per pixel line), in frame heights
  vec2 n = vec2(-d.y, d.x);
  float t = dot((uv - 0.5) * vec2(ratio, 1.0), n);
  float row = floor(t * 540.0);
  float clump = floor(t * 60.0);
  float rnd = 0.6 * hash(row + 17.0) + 0.4 * hash(clump + 311.0);

  float p = progress;
  float k = softness + 1e-4;
  // the lines rest just beyond the frame, past their soft edge
  float margin = k + 0.002;
  // the leading line eats the outgoing image, the trailing one gives back the incoming image;
  // they leave and arrive at rest beyond the frame so that both ends are exact
  float ta = clamp(p / 0.6, 0.0, 1.0);
  float tb = 1.0 - clamp((p - 0.4) / 0.6, 0.0, 1.0);
  // the leading line enters at once with a slight ease in, the trailing one eases out
  float ea = mix(ta, ta * ta * (2.2 - 1.2 * ta), 0.3);
  float eb = 1.0 - mix(tb, tb * tb * (2.2 - 1.2 * tb), 0.7);
  float a = mix(-margin, 1.0 + margin, ea);
  float b = mix(-margin, 1.0 + margin, eb);

  // the streaking is strongest at the middle of the sweep: 0 at both ends
  float h = 1.0 - abs(2.0 * p - 1.0);
  float split = 0.02 * chroma * h;
  // each row's streak starts a bit ahead of the line, ramping in from the line
  float ja = 0.04 * jitter * h * rnd * clamp((a - s) / 0.1, 0.0, 1.0);
  float jb = 0.04 * jitter * h * rnd * clamp((s - b) / 0.1, 0.0, 1.0);

  // outgoing: behind the leading line, repeat the pixels at the line
  vec4 fr = getFromColor(at(uv, s, smax(s, a + ja + split, k), d, ext));
  vec4 fg = getFromColor(at(uv, s, smax(s, a + ja, k), d, ext));
  vec4 fb = getFromColor(at(uv, s, smax(s, a + ja - split, k), d, ext));
  // incoming: ahead of the trailing line, repeat its pixels forward
  vec4 tr = getToColor(at(uv, s, -smax(-s, -b - jb - split, k), d, ext));
  vec4 tg = getToColor(at(uv, s, -smax(-s, -b - jb, k), d, ext));
  vec4 tbc = getToColor(at(uv, s, -smax(-s, -b - jb + split, k), d, ext));
  vec4 outgoing = vec4(fr.r, fg.g, fb.b, fg.a);
  vec4 incoming = vec4(tr.r, tg.g, tbc.b, tg.a);

  // between the lines, the streaks switch from the outgoing to the incoming image,
  // each row at its own place so that they look like streaks of different lengths
  float f = (a - s) / max(a - b, 1e-4);
  float w = s >= a ? 0.0 : s <= b ? 1.0
    : smoothstep(0.0, 1.0, clamp((f - 0.5 + 0.5 * jitter * (rnd - 0.5)) / 0.25 + 0.5, 0.0, 1.0));
  // a faint flicker along the streaks
  float flick = 1.0 + 0.06 * jitter * h * (hash(row * 3.0 + 5.0) - 0.5) * step(b, s) * step(s, a);
  vec4 c = mix(outgoing, incoming, w);
  return vec4(c.rgb * flick, c.a);
}
