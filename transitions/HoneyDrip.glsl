// Author: gre
// License: MIT
// Description: The outgoing image sags like honey hanging from the top of the frame: its bottom gathers into one heavy amber drop that pulls the middle into a thinning glossy thread, the thread snaps, the drop falls out of the frame and the rest springs back up, revealing the incoming image
// Tags: liquid, drip, gravity, organic, vertical, glossy

// @range(0.4, 0.8) When the thread snaps, as a part of the transition
uniform float snap; // = 0.55
// @range(0, 1) Strength of the glossy shading, amber depth and refraction
uniform float gloss; // = 0.7

const vec3 AMBER = vec3(1.0, 0.6, 0.18);

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float capsule(vec2 p, float y0, float y1, float r) {
  return length(vec2(p.x, p.y - clamp(p.y, y0, y1))) - r;
}

float dropSd(vec2 p, vec3 d) {
  vec2 q = (p - vec2(0.0, d.x)) / d.yz;
  // widest low, narrowing toward the thread
  q.x /= 1.0 + 0.22 * clamp(q.y, -1.0, 1.0);
  return (length(q) - 1.0) * min(d.y, d.z);
}

// p = (x from the center, depth from the top); b: band bottom, upper thread end, lower thread start, thread radius;
// d: drop center depth and radii; k: blend radius, kc: blend across the snapped thread
float honey(vec2 p, vec4 b, vec3 d, float k, float kc) {
  float upper = smin(p.y - b.x, capsule(p, min(b.x + b.w, b.y), b.y, b.w), k);
  float lower = smin(capsule(p, b.z, d.x, b.w), dropSd(p, d), k);
  return smin(upper, lower, kc);
}

vec4 transition(vec2 uv) {
  float t = progress;
  float W = 0.5 * ratio;
  float sn = clamp(snap, 0.05, 0.95);
  float u = min(t, sn) / sn;
  float s = u * (2.0 - u);
  float after = max(t - sn, 0.0) / (1.0 - sn);
  float rel = smoothstep(0.0, 1.0, after * 2.5);

  float aPre = mix(1.06, 0.2, s);
  // the band jerks up when released, wobbles once, then leaves
  float a = mix(aPre, -0.12, smoothstep(0.0, 1.0, after * 1.25)) - aPre * 0.25 * sin(after * 9.0) * exp(-after * 5.0);
  float rx = mix(W + 0.15, min(0.5 * W, 0.22), s);
  float ry = mix(0.55, min(1.25 * rx + 0.04, 0.3), s);
  float c0 = mix(0.58, 0.95 - ry, s * s);
  // lands the drop's top just past the bottom edge at the end
  float fall = (1.06 - c0 + ry) * after * (0.15 + 0.85 * after);
  float c = c0 + fall;
  float rn = mix(W, 0.013, pow(s, 0.6)) * (1.0 + 0.6 * rel);
  float k = mix(0.32, 0.09, s * s);
  float ys = mix(aPre, c0 - ry, 0.45);
  float yu = mix(ys, a, smoothstep(0.0, 1.0, after * 3.0));
  float yl = mix(ys, c0 - 0.8 * ry, smoothstep(0.0, 1.0, after * 1.2)) + fall;
  float kc = k * (1.0 - smoothstep(0.0, 1.0, after * 12.0)) + 1e-4;
  vec4 b = vec4(a, yu, yl, rn);
  vec3 d = vec3(c, rx, ry);

  vec2 p = vec2((uv.x - 0.5) * ratio, 1.0 - uv.y);
  float sd = honey(p, b, d, k, kc);
  vec2 e = vec2(0.002, 0.0);
  vec2 g = vec2(
    honey(p + e.xy, b, d, k, kc) - honey(p - e.xy, b, d, k, kc),
    honey(p + e.yx, b, d, k, kc) - honey(p - e.yx, b, d, k, kc)) / (2.0 * e.x);

  // the material keeps its top-to-bottom order: band, a sliver in the thread, the lower image in the drop
  float top = max(c - ry, a);
  float vTop = aPre + 0.1 * (1.0 - aPre) * clamp((top - a) / 0.1, 0.0, 1.0);
  float v = p.y < a ? p.y + aPre - a
    : p.y < top ? mix(aPre, vTop, (p.y - a) / max(top - a, 1e-4))
    : mix(vTop, 1.0, clamp((p.y - top) / (c + ry - top), 0.0, 1.0));
  // the shape is symmetric and each row is one span, so bisect its half-width
  float lo = 0.0;
  float hi = W;
  for (int i = 0; i < 10; i++) {
    float m = 0.5 * (lo + hi);
    if (honey(vec2(m, p.y), b, d, k, kc) < 0.0) lo = m; else hi = m;
  }
  // the band's bottom edge makes the span jump, so ease from the band's width into the thread's
  float wb = 0.5 * (lo + hi);
  float w = mix(W, wb, smoothstep(a, a + 1.5 * k, p.y));
  // narrow rows show only the middle of the picture, so the drop does not read as a fisheye
  float sx = clamp(p.x / max(mix(w, max(w, min(rx, W)), 0.6), 1e-3), -1.0, 1.0);

  float env = s * (1.0 - smoothstep(0.0, 1.0, after));
  float depth = clamp(-sd / clamp(0.6 * wb, 0.012, 0.18), 0.0, 1.0);
  float h = sqrt(depth * (2.0 - depth));
  // outward direction, y up; its x part fades on the center line, where the distance field creases
  vec2 nOut = vec2(g.x * smoothstep(0.0, 0.3 * w + 1e-3, abs(p.x)), -g.y) / max(length(g), 1e-3);
  vec3 n = normalize(vec3(nOut * (1.0 - depth) * s * gloss, mix(1.0, max(h, 0.05), s * gloss)));
  vec2 src = vec2(0.5 + 0.5 * sx, 1.0 - v) - n.xy * 0.03;
  vec4 img = getFromColor(clamp(mix(uv, src, s), 0.0, 1.0));

  vec3 l = normalize(vec3(-0.4, 0.55, 0.73));
  float dif = 1.0 + 0.45 * (dot(n, l) / l.z - 1.0);
  float rs = max(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0);
  float bulk = smoothstep(0.02, 0.12, wb) * smoothstep(a, a + k, p.y);
  float thick = depth * bulk;
  // light focused through the drop gathers inside the rim opposite the light
  float glow = bulk * smoothstep(0.0, 0.3, depth) * (1.0 - smoothstep(0.3, 1.0, depth)) * max(dot(nOut, -l.xy), 0.0);
  float amt = gloss * s;
  vec3 col = img.rgb * mix(1.0, dif, amt);
  col *= exp(-amt * (0.08 + thick) * vec3(0.0, 0.45, 1.2));
  col *= mix(vec3(1.0), vec3(0.55, 0.32, 0.1), 0.7 * amt * (1.0 - h) * (1.0 - h));
  col += amt * (1.3 * glow * AMBER + pow(rs, 50.0) + 0.12 * pow(rs, 8.0) * AMBER);
  img.rgb = col;

  float aa = 0.006;
  float inside = clamp(0.5 - sd / aa, 0.0, 1.0);
  vec4 bg = getToColor(uv);
  bg.rgb *= 1.0 - 0.45 * env * exp(-max(sd, 0.0) * 16.0);
  return mix(bg, img, inside);
}
