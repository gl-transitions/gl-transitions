// Author: gre
// License: MIT
// Description: The outgoing picture turns into the stacked layers of an area chart: wavy streams of the incoming picture swell up between its layers and squeeze them thinner while the layer borders undulate like live data, until the incoming streams fill the frame
// Tags: chart, waves, layers, squeeze, graphic

// @range(0, 1.5) How much the layers swell and thin along the frame
uniform float swell; // = 0.9
// @range(0, 0.03) Width of the light lines between the layers, in frame heights
uniform float line; // = 0.012
// @color Color of the lines between the layers
uniform vec4 lineColor; // = vec4(0.97, 0.96, 0.93, 1.0)

const int N = 5;

float ease(float t) {
  t = clamp(t, 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

float grow(float i, float x, float t) {
  float lag = 0.1 + 0.07 * sin(2.3 * x + 1.7 * i) + 0.03 * sin(5.1 * x - 2.9 * i);
  return ease((t - 0.09 * mod(3.0 * i, 5.0) - lag) / 0.34);
}

float data(float i, float x, float t, float env) {
  float w = sin(1.9 * x + 2.4 * i - 4.0 * t) + 0.6 * sin(3.7 * x - 1.3 * i - 6.0 * t);
  return exp(swell * env * 0.6 * w);
}

vec4 transition(vec2 uv) {
  float t = progress;
  float x = uv.x * ratio;
  float env = sin(3.14159 * t);
  float total = 0.0;
  for (int k = 0; k < N; k++) {
    float i = float(k);
    float s = grow(i, x, t);
    total += data(i, x, t, env) * (1.0 - s) + data(i + 7.0, x, t, env) * s;
  }
  float y = uv.y * total;
  float acc = 0.0;
  float edge = 1e3;
  vec4 c = vec4(0.0);
  for (int k = 0; k < N; k++) {
    float i = float(k);
    float s = grow(i, x, t);
    float hf = data(i, x, t, env) * (1.0 - s);
    float ht = data(i + 7.0, x, t, env) * s;
    float y0 = acc, y1 = acc + hf, y2 = y1 + ht;
    if (y >= y0 && y < y2) {
      c = y < y1
        ? getFromColor(vec2(uv.x, (i + (y - y0) / max(hf, 1e-5)) / float(N)))
        : getToColor(vec2(uv.x, (i + (y - y1) / max(ht, 1e-5)) / float(N)));
    }
    if (k > 0) edge = min(edge, abs(y - y0));
    edge = min(edge, abs(y - y1));
    acc = y2;
  }
  if (y >= acc) c = getToColor(vec2(uv.x, 1.0));
  edge /= total;
  float g = 0.5 * line * env;
  float m = smoothstep(g - 0.003, g + 0.003, edge) + 1.0 - smoothstep(0.0, 0.003, g);
  return mix(lineColor, c, clamp(m, 0.0, 1.0));
}
