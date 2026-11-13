// Author: gre
// License: MIT
// Description: The picture loses its horizontal hold like an old TV: it shears into diagonal bands that slide sideways and wrap around, separated by a slanted blanking bar that carries the incoming image in, then the shear straightens, wobbles and locks
// Tags: retro, horizontal, shear, scanlines

// @range(2, 6, 1) Number of times the picture slips sideways before it locks
uniform int slips; // = 3
// @range(0, 4) How far the lines lag from top to bottom at the worst of the tearing, in picture widths
uniform float shear; // = 1.25
// @range(0, 0.5) Width of the blanking bar between the copies of the picture
uniform float barWidth; // = 0.14
// @color Color of the blanking bar
uniform vec4 barColor; // = vec4(0.02, 0.02, 0.03, 1.0)

float slipCount() {
  return max(float(slips), 1.0);
}

// The picture stream at x: outgoing copies, then incoming ones, with a bar between them
vec4 stream(float x, float y, float unsync) {
  float period = 1.0 + barWidth;
  float n = floor(x / period);
  float xm = x - n * period;
  vec2 q = vec2(min(xm, 1.0), y);
  vec4 c = n >= floor(0.5 * slipCount() + 0.5) ? getToColor(q) : getFromColor(q);
  // distance to the nearest bar, negative inside it
  float d = min(xm, 1.0 - xm);
  // the picture overshoots to white next to the bar
  float g = max(1.0 - d / 0.05, 0.0);
  c.rgb += 0.3 * unsync * g * g * c.a;
  float soft = min(0.012 * unsync, 0.5 * barWidth) + 1e-5;
  return mix(barColor, c, clamp(d / soft, 0.0, 1.0));
}

vec4 transition(vec2 uv) {
  float period = 1.0 + barWidth;
  // the sync error grows then fades; the slip is its integral, a whole number of periods
  float t = min(progress / 0.88, 1.0);
  float err = 16.0 * t * t * (1.0 - t) * (1.0 - t);
  float slip = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  // the hold overshoots and wobbles before it locks
  float u = clamp((progress - 0.74) / 0.26, 0.0, 1.0);
  float lock = u * (1.0 - u) * (1.0 - u);
  float tilt = -0.5 * max(shear, 0.5) * lock * sin(9.42478 * u);
  float unsync = min(err + 3.0 * lock, 1.0);
  // lines lower in the frame lag behind, and ripple a little
  float ripple = 0.012 * sin(uv.y * 9.0 + progress * 40.0) + 0.005 * sin(uv.y * 31.0 - progress * 70.0);
  float x = uv.x + period * (slipCount() * slip + shear * err * (1.0 - uv.y) + tilt * (1.0 - uv.y)) + err * ripple;
  // the slip smears the picture sideways
  float blur = 0.002 * err * slipCount();
  vec4 c = stream(x, uv.y, unsync);
  if (blur > 0.0) {
    for (int i = 0; i < 4; i++) {
      c += stream(x + blur * (float(i) - 1.5), uv.y, unsync);
    }
    c /= 5.0;
  }
  // the unsynced picture dims and shows its scanlines
  c.rgb *= 1.0 - unsync * (0.1 + 0.08 * sin(uv.y * 480.0));
  return c;
}
