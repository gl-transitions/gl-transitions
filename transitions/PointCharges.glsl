// Author: gre
// License: MIT
// Description: Charges appear in the outgoing picture, each holding a small view of the incoming one in a glass bead; they orbit and grow while the outgoing picture bends and pours around them, then one of them takes the center and opens onto the incoming picture as the others are pushed out of the frame
// Tags: conformal, field, bubbles, liquid, warp

// @range(2, 6, 1) Number of charges
uniform float charges; // = 4.0
// @range(-1.5, 1.5) Turns the charges make around the center
uniform float turns; // = 0.6
// @range(0, 1) Glassy rim where the two pictures meet
uniform float rim; // = 0.7

const float TAU = 6.283185307;

vec2 mirrorUv(vec2 u) {
  return 1.0 - abs(1.0 - mod(u, 2.0));
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  float m = min(ratio, 1.0);
  // the beads crop the pictures to this disc, so that little beyond their borders is seen
  float R = 0.5 * m;
  // 0.53: the frame's corners stay clear of the soft edge at both ends
  float L = log(0.53 * length(asp) / R);
  float n = clamp(floor(charges + 0.5), 2.0, 6.0);
  float enter = smoothstep(0.0, 0.28, p);
  float g0 = mix(mix(L, 0.45, enter), -L, smoothstep(0.4, 1.0, p));
  float world = exp(-(L + 0.2) * enter) * (1.0 - smoothstep(0.35, 1.0, p));
  float s = smoothstep(0.34, 0.95, p);
  float left = 1.0 - smoothstep(0.45, 0.9, p);
  float turn = TAU * turns * smoothstep(0.0, 1.0, p);
  float e = rim * smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.8, 1.0, p));
  float aa = 0.001 * smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.9, 1.0, p));
  vec2 spread = min(asp, 1.35 * m) / R;
  float push = 2.0 * max(ratio, 1.0) / m;

  // 1e-5: a pixel exactly on a charge has no field
  vec2 z = ((uv - 0.5) * asp + 1e-5) / R;
  vec4 zx = z.x + aa / R * vec4(1.5, 0.5, -0.5, -1.5);
  vec4 zy = z.y + aa / R * vec4(0.5, -1.5, 1.5, -0.5);
  vec4 wx = world * zx, wy = world * zy;
  for (int i = 0; i < 6; i++) {
    float k = float(i);
    if (k >= n) break;
    float x = clamp((p - 0.03 * k) / 0.4, 0.0, 1.0);
    // swells at once, then settles
    float q = min(1.0 / n, 0.4) * x * x * (2.0 - x) / (x + 0.03);
    float a = TAU * (k / n + 0.11) + turn;
    vec2 c = (0.31 - 0.05 * cos(TAU * k * 0.618)) * vec2(cos(a), sin(a)) * spread;
    if (i == 0) {
      q = mix(q, 1.0, s);
      c *= 1.0 - s;
    } else {
      q *= left;
      c *= 1.0 + push * s;
    }
    vec4 dx = zx - c.x, dy = zy - c.y;
    vec4 d = q / max(dx * dx + dy * dy, 1e-12);
    wx += d * dx;
    wy -= d * dy;
  }

  vec4 sum = vec4(0.0);
  for (int j = 0; j < 4; j++) {
    vec2 w = j == 0 ? vec2(wx.x, wy.x) : j == 1 ? vec2(wx.y, wy.y) : j == 2 ? vec2(wx.z, wy.z) : vec2(wx.w, wy.w);
    float l = max(dot(w, w), 1e-9);
    float g = 0.5 * log(l) - g0;
    vec4 f = getFromColor(mirrorUv(w * R / asp + 0.5));
    vec4 t = getToColor(mirrorUv(vec2(w.x, -w.y) / l * R / asp + 0.5));
    vec4 col = mix(vec4(f.rgb * f.a, f.a), vec4(t.rgb * t.a, t.a), smoothstep(-0.02, 0.02, g));
    col.rgb *= 1.0 - 0.5 * e * exp(-abs(g) * 6.0);
    col.rgb += 0.45 * e * exp(-(g - 0.12) * (g - 0.12) * 200.0) * col.a;
    sum += col;
  }
  return sum.a > 0.0 ? vec4(sum.rgb / sum.a, 0.25 * sum.a) : vec4(0.0);
}
