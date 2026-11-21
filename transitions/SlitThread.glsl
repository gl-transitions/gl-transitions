// Author: gre
// License: MIT
// Description: A slit is cut across the middle of the outgoing image and the incoming image is pulled down through it from behind, bulging the old picture above the slit, then swings back up in front of it to cover the frame
// Tags: slit, thread, paper, layers, through

// @range(0.5, 0.95) Width of the incoming sheet while it passes through the slit
uniform float sheet; // = 0.84
// @range(0, 1) Strength of shadows and the bulge of the hidden sheet
uniform float depth; // = 0.8

const vec2 LIGHT = vec2(-0.6, 0.8);

vec2 rectE(vec2 q, vec2 lo, vec2 hi, vec2 box) {
  return max(lo - q, q - hi) * box;
}

float rectD(vec2 q, vec2 lo, vec2 hi, vec2 box) {
  vec2 e = rectE(q, lo, hi, box);
  return max(e.x, e.y);
}

float bump(vec2 q, vec2 lo, vec2 hi, vec2 box, float y0) {
  vec2 e = rectE(q, lo, hi, box) + 0.1;
  float d = length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - 0.1;
  return (1.0 - smoothstep(-0.12, 0.05, d)) * smoothstep(y0, y0 + 0.1, q.y);
}

vec4 transition(vec2 uv) {
  vec2 box = vec2(ratio, 1.0);
  float px = 1.0 / 200.0;
  float t = progress;
  float k = clamp(depth, 0.0, 1.0);
  float s0 = clamp(sheet, 0.5, 0.95);
  float y0 = 0.5;

  // down then up as one swing: the phase lengths match the deceleration into the turn to the acceleration out of it
  float yStart = y0 + 0.012;
  // at the turn the sheet's top edge and its AA fringe sit just under the slit, so the layer switch is invisible
  float yTurn = y0 - 0.004 - 1.5 * px - s0;
  float t0 = 0.06;
  float tTurn = t0 + (1.0 - t0) / (1.0 + sqrt(max(-yTurn, 0.0) / (yStart - yTurn)));
  float down = smoothstep(t0, tTurn, t);
  float rise = smoothstep(tTurn, 1.0, t);
  float s = mix(s0, 1.0, rise);
  float yb = mix(mix(yStart, yTurn, down), 0.0, rise);
  vec2 lo = vec2(0.5 - 0.5 * s, yb), hi = vec2(0.5 + 0.5 * s, yb + s);
  float through = step(tTurn, t);
  float threading = smoothstep(t0, t0 + 0.12, t) * (1.0 - smoothstep(tTurn - 0.1, tTurn, t));
  float enter = smoothstep(t0, t0 + 0.15, t);
  float hidden = (1.0 - through) * enter;

  float cut = smoothstep(0.0, 0.12, t);
  float halfL = (0.5 * s0 + 0.035) * cut;
  float along = clamp(abs(uv.x - 0.5) / max(halfL, 1e-4), 0.0, 1.0);
  float onSlit = (1.0 - smoothstep(halfL - px, halfL, abs(uv.x - 0.5))) * cut;
  float gap = (0.004 + 0.007 * threading * (1.0 - along * along)) * cut;
  float dy = uv.y - y0;

  vec2 grad = vec2(0.0);
  if (hidden * k > 0.0) {
    vec2 e = vec2(0.01, 0.0);
    float bx = bump(uv + e.xy, lo, hi, box, y0) - bump(uv - e.xy, lo, hi, box, y0);
    float by = bump(uv + e.yx, lo, hi, box, y0) - bump(uv - e.yx, lo, hi, box, y0);
    grad = vec2(bx, by) * hidden * k;
  }
  vec4 c = getFromColor(uv - 0.01 * grad);
  c.rgb *= 1.0 - 1.2 * dot(grad, LIGHT);

  c.rgb *= 1.0 - onSlit * 0.85 * (1.0 - smoothstep(gap - 0.5 * px, gap + 0.5 * px, abs(dy)));
  float lipLit = onSlit * smoothstep(gap - 0.5 * px, gap + 0.5 * px, -dy) * (1.0 - smoothstep(gap, gap + 0.012, -dy));
  c.rgb += 0.12 * lipLit;

  float below = 1.0 - smoothstep(-0.5 * px, 0.5 * px, uv.y - (y0 - gap));
  float front = mix(below, 1.0, through);
  float lift = mix(1.0, 0.6, rise);
  float sh = rectD(uv - vec2(0.008, -0.014) * lift, lo, hi, box);
  float shadowFront = mix(below, 1.0, smoothstep(tTurn, tTurn + 0.08, t));
  c.rgb *= 1.0 - 0.45 * k * shadowFront * (1.0 - smoothstep(-0.02, 0.025, sh)) * (1.0 - rise * rise) * enter;

  float d = rectD(uv, lo, hi, box);
  // AA fades out so the full-frame border lands exact
  float aa = px * (1.0 - rise) + 1e-4;
  float cov = (1.0 - smoothstep(-aa, aa, d - 0.004 * rise)) * front;
  vec4 to = getToColor(clamp((uv - lo) / s, 0.0, 1.0));
  float lip = (y0 - gap - uv.y) / px;
  float lipShade = threading * step(0.0, lip);
  to.rgb *= 1.0 - 0.5 * k * lipShade * exp(-lip / 5.0);
  to.rgb *= 1.0 - 0.12 * k * smoothstep(-0.01, 0.0, d) * (1.0 - rise);
  return mix(c, to, cov);
}
