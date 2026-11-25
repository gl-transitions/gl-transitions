// Author: gre
// License: MIT
// Description: The outgoing picture's own colors move to redraw the incoming one, each point finding the color around it that best matches what it must become; then the colors turn true
// Tags: morph, color, rearrange, organic

// @param How far a pixel can go to find its color, in frame heights
// @range(0.2, 1)
uniform float reach; // = 0.75
// @param How strictly the colors must match
// @range(4, 60)
uniform float strictness; // = 24.0

const int TAPS = 31;

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec3 tone(vec3 c) {
  float y = dot(c, vec3(0.299, 0.587, 0.114));
  return vec3(y, 0.6 * (c.r - y), 0.6 * (c.b - y));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec4 transition(vec2 uv) {
  float grow = smoothstep(0.0, 0.8, progress);
  float r = 0.9 * reach * pow(grow, 1.4);
  vec4 b = pm(getToColor(uv));
  vec3 goal = tone(b.rgb);
  float k = strictness * 1.6 * smoothstep(0.0, 0.25, progress);
  vec4 sum = vec4(0.0);
  float total = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float f = float(i);
    float a = f * 2.399963;
    vec2 o = r * pow(f / float(TAPS - 1), 0.7) * vec2(cos(a), sin(a));
    vec4 c = pm(getFromColor(fold(uv + o / vec2(ratio, 1.0))));
    // the floor keeps the sum above zero where nothing matches
    float w = exp(-k * (length(tone(c.rgb) - goal) + 0.2 * length(o))) + 1e-7;
    sum += c * w;
    total += w;
  }
  vec4 col = mix(sum / total, b, smoothstep(0.6, 1.0, progress));
  return col.a > 0.0 ? vec4(col.rgb / col.a, col.a) : vec4(0.0);
}
