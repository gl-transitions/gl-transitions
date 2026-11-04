// Author: gre
// License: MIT
// Description: The edit cuts back and forth between the two images, through brief blank frames, faster and faster, staying longer on the incoming image each time until it lands on it
// Tags: cut, flicker, strobe, flash

// @range(1, 6, 1) Number of times the outgoing image flickers back
uniform int flickers; // = 3
// @range(0, 1) Length of the blank frames before each cut (0 for clean cuts)
uniform float flash; // = 0.5
// @color Color of the blank frames
uniform vec4 color; // = vec4(1.0, 1.0, 1.0, 1.0)
// @range(0, 1) Brief exposure pop right after each cut
uniform float punch; // = 0.25

const int MAX_FLICKERS = 6;
// part of the progress over which the images alternate; the incoming image then holds
const float SPAN = 0.9;
// the outgoing shots shrink: the last one lasts this share of the first
const float FROM_LAST = 0.35;
// the first incoming shot, relative to the first outgoing one; the incoming shots then grow longer, by TO_GROW at the last one
const float TO_FIRST = 0.8;
const float TO_GROW = 0.4;
// blank frames: at most this share of the shot they end, and at most this much progress
const float BLANK_SHARE = 0.5;
const float BLANK_MAX = 0.06;
// how long the exposure pop lasts on the final hold
const float POP = 0.08;

float toGrowth(float i, float n) {
  return 1.0 + TO_GROW * (n > 1.0 ? i / (n - 1.0) : 0.0);
}

vec4 transition(vec2 uv) {
  int count = flickers < 1 ? 1 : (flickers > MAX_FLICKERS ? MAX_FLICKERS : flickers);
  float n = float(count);
  // the outgoing shot i lasts a * q^i (i = 0..n), the incoming one after it a * TO_FIRST * toGrowth(i)
  float q = pow(FROM_LAST, 1.0 / n);
  float toSum = n * (n > 1.0 ? 1.0 + 0.5 * TO_GROW : 1.0);
  float a = SPAN / ((1.0 - q * FROM_LAST) / (1.0 - q) + TO_FIRST * toSum);

  // find the shot at progress, which starts at t: walk the back and forth
  bool incoming = true;
  float len = POP;
  bool last = true;   // the final hold on the incoming image
  bool first = false; // the opening shot of the outgoing image, before any cut
  float t = 0.0;
  float fromLen = a;
  for (int i = 0; i <= MAX_FLICKERS; i++) {
    if (progress < t + fromLen) {
      incoming = false;
      len = fromLen;
      last = false;
      first = i == 0;
      break;
    }
    t += fromLen;
    if (i >= count) break;
    float toLen = a * TO_FIRST * toGrowth(float(i), n);
    if (progress < t + toLen) {
      len = toLen;
      last = false;
      break;
    }
    t += toLen;
    fromLen *= q;
  }
  float s = clamp((progress - t) / len, 0.0, 1.0);

  // blank frames end every shot but the final hold
  float blank = flash * min(BLANK_SHARE * len, BLANK_MAX);
  if (!last && progress >= t + len - blank) return color;

  vec4 c = incoming ? getToColor(uv) : getFromColor(uv);
  float pop = first ? 0.0 : punch * (1.0 - s) * (1.0 - s);
  // brighten toward white without clipping values already above it
  c.rgb += min(c.rgb * pop, max(1.0 - c.rgb, 0.0));
  return c;
}
