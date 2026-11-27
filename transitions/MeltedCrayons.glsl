// Author: gre
// License: MIT
// Description: A row of crayons melts along the top edge and their colored wax runs down over the outgoing image as a wavy sheet led by wobbly drips with a heavy bead at each tip; through the wax the incoming image shows, stained with the crayon colors in the fresh drips and clearing as the wax settles
// Tags: drip, wax, melt, color, organic, vertical, craft

// @range(3, 20) Number of crayons across a landscape frame; portrait frames keep the same crayon size
uniform float crayons; // = 8.0
// @range(0, 1) How strongly the fresh wax stains and bends the incoming image
uniform float wax; // = 0.75
// @color First crayon color
uniform vec4 colorA; // = vec4(0.92, 0.18, 0.22, 1.0)
// @color Second crayon color
uniform vec4 colorB; // = vec4(1.0, 0.8, 0.15, 1.0)
// @color Third crayon color
uniform vec4 colorC; // = vec4(0.15, 0.45, 0.95, 1.0)

vec3 hash3(float n) {
  vec3 p = fract(vec3(n) * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yzx + 33.33);
  return fract((p.xxy + p.yzz) * p.zyx);
}

vec4 crayonColor(float k) {
  float u = fract(k * 0.382 + 0.05) * 3.0;
  vec4 c = mix(colorA, colorB, clamp(u, 0.0, 1.0));
  c = mix(c, colorC, clamp(u - 1.0, 0.0, 1.0));
  return mix(c, colorA, clamp(u - 2.0, 0.0, 1.0));
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float t = progress;
  float sp = max(ratio, 1.0) / crayons;
  float x = uv.x * ratio;
  float y = 1.0 - uv.y;
  float cx = x / sp;
  float k0 = floor(cx);
  float e = t * (0.45 + 0.55 * t);
  // starts above the frame by more than the fillet, ends below it with the waves
  float base = mix(-0.02, 1.08, e);
  float sheet = base + (0.035 * sin(cx * 6.2832 + 1.3) + 0.02 * sin(x * 7.1 + 2.0)) * min(t * 6.0, 1.0);
  float dS = y - sheet;
  float dD = 1e3;
  float dq = 0.0;
  vec4 dcol = vec4(0.0);
  float aa = 0.0015;
  for (int i = -1; i <= 1; i++) {
    float k = k0 + float(i);
    vec4 kcol = crayonColor(k);
    for (int j = 0; j < 2; j++) {
      vec3 g = hash3(k * 2.0 + float(j) + 17.0);
      float r = sp * mix(0.07, 0.13, g.x) * (1.0 - 0.4 * float(j));
      float xc = (k + 0.5 + (float(j) - 0.5) * 0.5 + 0.2 * (g.y - 0.5)) * sp;
      xc += (0.006 * sin(y * 9.0 + g.z * 6.28) + 0.003 * sin(y * 23.0 + g.x * 6.28)) * min(sp * 4.0, 1.0);
      float tip = base + mix(0.2, 1.0, g.z) * t * (2.0 - t);
      float rb = r * 1.35;
      float s = tip - y;
      float rr = mix(rb, r, smoothstep(rb, 3.0 * rb, s));
      float d = length(vec2(x - xc, y - clamp(y, min(base - 0.2, tip - rb), tip - rb))) - rr;
      float hd = clamp(0.5 + 0.5 * (dD - d) / 0.01, 0.0, 1.0);
      dq = mix(dq, clamp((x - xc) / rr, -1.0, 1.0), hd);
      dcol = mix(dcol, kcol, hd);
      dD = smin(dD, d, 0.01);
    }
  }
  float dd = smin(dS, dD, 0.03);
  float mask = 1.0 - smoothstep(-aa, aa, dd);
  float inDrip = 1.0 - smoothstep(-0.02, 0.0, dD - dS);
  float fresh = mix(0.4 - 0.4 * smoothstep(0.0, 0.25, -dS), 1.0, inDrip) * (1.0 - t * t * t);
  float rim = smoothstep(-0.03, 0.0, dd);
  float bead = sqrt(1.0 - dq * dq);
  vec2 off = vec2(dq * bead * inDrip / ratio, -rim * (1.0 - inDrip)) * 0.015 * wax * fresh;
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(mirror(uv + off));
  float c0 = floor(cx - 0.5);
  vec4 col = mix(crayonColor(c0), crayonColor(c0 + 1.0), smoothstep(0.3, 0.7, cx - 0.5 - c0));
  col = mix(col, dcol, inDrip);
  float lum = dot(b.rgb, vec3(0.299, 0.587, 0.114));
  vec3 stained = col.rgb * (0.5 + 0.65 * lum) + 0.1 * bead * (-dq) * inDrip;
  b.rgb = mix(b.rgb, stained, wax * col.a * fresh * 0.8);
  return mix(a, b, mask);
}
