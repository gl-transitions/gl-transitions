// Author: gre
// License: MIT
// Description: The outgoing image is kneaded like dough: its two halves squeeze and slide past each other into two rows, again and again, until the picture is drawn out into thin layers; the layers of the incoming image are pressed in between them, then the incoming image is unkneaded back into one picture
// Tags: knead, fold, stack, stretch, stripes, rhythm, shadow

// @range(1, 5, 1) Number of kneads on each side (each one stacks the picture into twice as many layers)
uniform int kneads; // = 3
// @range(0, 1) Depth of the shading on the layers and of the shadow the sliding half casts
uniform float shadow; // = 0.5
// @color Color seen in the corners the halves uncover while they slide
uniform vec4 backColor; // = vec4(0.1, 0.1, 0.1, 1.0)

vec4 img(vec2 q, bool incoming) {
  return incoming ? getToColor(q) : getFromColor(q);
}

// undoes n complete kneads: the bottom row came from the left half, the top row from the right half
vec2 unknead(vec2 q, int n) {
  for (int i = 0; i < 5; i++) {
    if (i >= n) break;
    q = q.y < 0.5 ? vec2(0.5 * q.x, 2.0 * q.y) : vec2(0.5 + 0.5 * q.x, 2.0 * q.y - 1.0);
  }
  return q;
}

// unknead of (row + t) / 2^n, with the row taken from its bits so t = 1 stays in that row
vec2 unkneadRow(float x, float row, float t, int n) {
  float h = exp2(float(n));
  for (int i = 0; i < 5; i++) {
    if (i >= n) break;
    h *= 0.5;
    float hi = step(h, row);
    row -= hi * h;
    x = 0.5 * x + 0.5 * hi;
  }
  return vec2(x, t);
}

float box(vec2 p, vec2 lo, vec2 hi, vec2 soft) {
  vec2 d = min(p - lo, hi - p) / soft;
  return clamp(min(d.x, d.y), 0.0, 1.0);
}

// rounded layer lit from above; equal at t = 0 and 1 so stacked layers meet without a seam
float layerShade(float t, float amount) {
  float c = 2.0 * t - 1.0;
  float c2 = c * c;
  return 1.0 + amount * (0.25 * c * (1.0 - c2) - 0.55 * c2 * c2);
}

float creases(float y, float rows, float amount) {
  return layerShade(fract(y * rows), amount);
}

// n complete kneads, then the next one at stage s; g fades the layer shading in and out over the transition
vec4 kneaded(vec2 uv, int n, float s, bool incoming, float g) {
  float env = 4.0 * s * (1.0 - s);
  float rows = exp2(float(n));
  float amount = shadow * g;
  // widening leads squashing so the corners they uncover stay small
  vec2 st = vec2(smoothstep(0.0, 0.75, s), smoothstep(0.25, 1.0, s));
  // edges soften only once the halves overlap, so no gap line shows where they meet
  vec2 soft = vec2(0.004 / ratio, 0.004) * smoothstep(0.0, 0.3, st.x) * smoothstep(0.0, 0.3, 1.0 - st.y) + 1e-6;
  vec2 hiL = vec2(0.5 + 0.5 * st.x, 1.0 - 0.5 * st.y);
  vec2 loR = vec2(0.5 - 0.5 * st.x, 0.5 * st.y);
  vec2 l = uv / hiL;
  vec2 r = (uv - loR) / (1.0 - loR);
  vec2 xs = vec2(0.1 / ratio, 0.1);
  // shading waits for the halves to separate so no seam shows at the cut
  float lift = env * smoothstep(0.0, 0.3, st.x);

  vec4 bottom = img(unknead(vec2(0.5 * l.x, l.y), n), incoming);
  bottom.rgb *= creases(l.y, rows, amount) * (1.0 - 0.7 * shadow * lift * (1.0 - smoothstep(0.0, xs.x, hiL.x - uv.x)));
  vec4 c = mix(backColor, bottom, box(uv, vec2(-1.0), hiL + soft, soft));

  vec2 off = vec2(0.02 / ratio, -0.03) * lift;
  float sh = 1.0 - smoothstep(0.0, 0.05, -min(ratio * min(uv.x - off.x - loR.x, 1.0 - uv.x + off.x), min(uv.y - off.y - loR.y, 1.0 - uv.y + off.y)));
  c.rgb *= 1.0 - shadow * 0.6 * lift * sh;

  vec4 top = img(unknead(vec2(0.5 + 0.5 * r.x, r.y), n), incoming);
  top.rgb *= creases(r.y, rows, amount) * (1.0 + 0.08 * lift) * (1.0 - 0.7 * shadow * lift * (1.0 - smoothstep(0.0, xs.x, uv.x - loR.x)));
  return mix(c, top, box(uv, loR, vec2(2.0), soft));
}

// incoming layers pressed in under each outgoing one, from alternate sides, until they fill the rows
vec4 interleave(vec2 uv, int n, float w, float g) {
  float rows = exp2(float(n));
  float amount = shadow * g;
  float y = uv.y * rows;
  float row = floor(y);
  float t = y - row;
  float side = mod(row, 2.0) < 1.0 ? uv.x : 1.0 - uv.x;
  float f = smoothstep(0.0, 1.0, clamp(1.7 * w - 0.7 * side, 0.0, 1.0));
  float tIn = clamp(t / max(f, 1e-4), 0.0, 1.0);
  float tOut = clamp((t - f) / max(1.0 - f, 1e-4), 0.0, 1.0);
  vec4 a = getToColor(unkneadRow(uv.x, row, tIn, n));
  vec4 b = getFromColor(unkneadRow(uv.x, row, tOut, n));
  a.rgb *= layerShade(tIn, amount);
  b.rgb *= layerShade(tOut, amount);
  // squeezed layers get darker toward their tip, as they thin out
  a.rgb *= 1.0 - 0.4 * shadow * (1.0 - smoothstep(0.0, 0.5, f));
  b.rgb *= 1.0 - 0.4 * shadow * (1.0 - smoothstep(0.0, 0.5, 1.0 - f));
  // the shift keeps row boundaries on the full layer when the other one is empty
  float edge = 0.0015 * min(1.0, 8.0 * f * (1.0 - f)) + 1e-6;
  return mix(a, b, smoothstep(-edge, edge, (t - f) / rows + edge * (1.0 - 2.0 * f)));
}

vec4 transition(vec2 uv) {
  int kn = int(clamp(float(kneads), 1.0, 5.0));
  float n = float(kn);
  const float SWAP = 1.2;
  float g = smoothstep(0.0, 0.12, progress) * smoothstep(0.0, 0.12, 1.0 - progress);
  float u = progress * (2.0 * n + SWAP);
  if (u < n) {
    float k = floor(u);
    return kneaded(uv, int(k), smoothstep(0.0, 1.0, u - k), false, g);
  }
  float v = 2.0 * n + SWAP - u;
  if (v < n) {
    float k = floor(v);
    return kneaded(uv, int(k), smoothstep(0.0, 1.0, v - k), true, g);
  }
  return interleave(uv, kn, (u - n) / SWAP, g);
}
