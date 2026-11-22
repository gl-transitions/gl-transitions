// Author: gre
// License: MIT
// Description: The outgoing image parts like a theater tableau curtain: each half is drawn up and out toward its top corner, opening a high rounded arch while the fabric gathers into pleats fanning toward the corners, then the two swags fly up out of the frame
// Tags: 3d, fold, split, reveal, shadow

// @range(2, 16, 1) Number of pleats in each half (fewer in a portrait image)
uniform float folds; // = 6.0
// @range(0, 1) Depth of the shading on the pleats and swags
uniform float shading; // = 0.7
// @range(0.2, 0.9) Height the swags are drawn up to before they fly out
uniform float hitch; // = 0.6

const float PI = 3.141592653589793;

// the opening edge: a superellipse from the top middle to the hem corner c, then the hem down to the
// outer leg; it rises with x, so it inverts both ways for an exact distance
float edgeX(float y, vec2 c, float k, float q) {
  if (y >= c.y) {
    float t = clamp((1.0 - y) / max(1.0 - c.y, 1e-4), 0.0, 1.0);
    return 0.5 - (0.5 - c.x) * pow(max(1.0 - pow(1.0 - t, q), 0.0), 1.0 / q);
  }
  // continued below the outer leg so nothing there counts as an edge
  float r = (y / max(c.y, 1e-4) - k) / (1.0 - k);
  return c.x * (r >= 0.0 ? sqrt(r) : -sqrt(-r));
}

float edgeY(float x, vec2 c, float k, float q) {
  if (x >= c.x) {
    float b = clamp((0.5 - x) / max(0.5 - c.x, 1e-4), 0.0, 1.0);
    return 1.0 - (1.0 - c.y) * (1.0 - pow(max(1.0 - pow(b, q), 0.0), 1.0 / q));
  }
  float r = x / c.x;
  return c.y * (k + (1.0 - k) * r * r);
}

vec4 transition(vec2 uv) {
  float p = progress;
  float G = smoothstep(0.0, 0.62, p);
  float f = clamp((p - 0.42) / 0.58, 0.0, 1.0);
  float fly = f * f * (3.0 - 2.0 * f);
  // the outer legs rise to k of the hitch height; the lift keeps accelerating so the swags leave at speed
  float k = 0.7 * fly;
  float lift = (1.08 - k * hitch) * f * f;
  float bunch = clamp(0.2 / ratio, 0.1, 0.18);
  vec2 c = vec2(0.5 - (0.5 - bunch) * G, hitch * smoothstep(0.0, 0.8, G));
  // a narrow wedge opening from the hem first, rounding into an arch as it widens
  float q = mix(0.6, 2.0, smoothstep(0.0, 0.7, G));
  float right = step(0.5, uv.x);
  float x = mix(uv.x, 1.0 - uv.x, right);
  float y = uv.y - lift;

  float e = edgeX(y, c, k, q);
  float dx = (e - x) * ratio;
  float dy = y - edgeY(x, c, k, q);
  float d = dx * abs(dy) / max(length(vec2(dx, dy)), 1e-6);
  float w = 0.002 * G + 1e-4;
  float inside = clamp(1.0 + d / w, 0.0, 1.0);

  float span = mix(c.x, e, step(c.y, y));
  float u = clamp(x / max(span, 1e-4), 0.0, 1.0);
  float hem = c.y * mix(u * u, 1.0, k);
  float v = clamp((1.0 - y) / max(1.0 - hem, 1e-4), 0.0, 1.0);

  float n = max(2.0, floor(folds * min(ratio, 1.0) + 0.5));
  // a slow wobble keeps the pleats from looking machined
  float a = 2.0 * PI * n * u + 0.7 * sin(PI * n * u * 0.73 + 1.3);
  float squeeze = 1.0 - 2.0 * span;
  float amp = G * mix(0.3, 0.95, squeeze) * (0.8 + 0.2 * sin(PI * n * u * 0.41 + 0.4));
  float su = clamp(u + amp * sin(a) / (2.0 * PI * n), 0.0, 1.0);
  vec4 from = getFromColor(vec2(mix(0.5 * su, 1.0 - 0.5 * su, right), 1.0 - v));

  float slope = 2.2 * amp * cos(a);
  float tilt = 1.1 * G * v * v * (0.3 + 0.7 * u);
  vec3 nrm = normalize(vec3(-slope, -tilt, 1.0));
  // lit in each half's mirrored frame so both swags stay symmetric
  vec3 L = normalize(vec3(-0.35, 0.6, 1.0));
  float diffuse = max(dot(nrm, L), 0.0) / L.z;
  float sheen = pow(max(dot(nrm, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), 10.0);
  float crease = 0.5 + 0.5 * sin(a);
  float edge = exp(-max(d, 0.0) * 70.0);
  float light = diffuse * (1.0 - 0.5 * crease * crease * amp) * (1.0 - 0.3 * squeeze * v * G) * (1.0 - 0.3 * edge)
    + 0.22 * sheen * amp;
  from.rgb *= mix(1.0, light, shading * smoothstep(0.0, 0.25, G));

  vec4 to = getToColor(uv);
  float shadow = 0.5 * shading * exp(max(-d, 0.0) * -30.0) * G * (1.0 - fly);
  to.rgb *= 1.0 - shadow;
  return mix(to, from, inside);
}
