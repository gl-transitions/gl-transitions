// Author: gre
// License: MIT
// Description: The outgoing image rolls faster and faster, like an old TV losing its vertical hold, then the roll slows down and locks on the incoming image
// Tags: retro, vertical, scanlines

// @range(1, 8) Number of frames that roll by
uniform int rolls; // = 3
// @range(0, 0.5) Height of the bar between the frames
uniform float barHeight; // = 0.12
// @color Color of the bar between the frames
uniform vec4 barColor; // = vec4(0.0, 0.0, 0.0, 1.0)

// The rolling picture at a vertical position y, in frames of height 1 + barHeight
vec4 picture(vec2 uv, float y, float m) {
  float period = 1.0 + barHeight;
  y = mod(y, period);
  if (y > 1.0) return barColor;
  vec2 q = vec2(uv.x, y);
  return mix(getFromColor(q), getToColor(q), m);
}

vec4 transition(vec2 uv) {
  float period = 1.0 + barHeight;
  // smooth start and stop: the picture locks again after a whole number of frames
  float s = progress * progress * (3.0 - 2.0 * progress);
  float offset = period * fract(float(rolls) * s);
  float speed = 4.0 * progress * (1.0 - progress); // 0 at both ends, 1 in the middle
  float m = smoothstep(0.42, 0.58, progress); // the channel changes at full speed
  // the horizontal sync wobbles a little
  vec2 p = uv + vec2(0.004 * speed * sin(uv.y * 9.0 + progress * 30.0), 0.0);
  // vertical motion blur
  vec4 c = vec4(0.0);
  for (int i = 0; i < 5; i++) {
    c += picture(p, p.y + offset - 0.0015 * float(rolls) * speed * float(i), m);
  }
  c /= 5.0;
  // scanlines and a flickering brightness
  float scan = 0.5 + 0.5 * sin(uv.y * 400.0);
  float flicker = 0.08 * (0.5 + 0.5 * sin(progress * 97.0));
  c.rgb *= 1.0 - speed * (0.08 * scan + flicker);
  return c;
}
