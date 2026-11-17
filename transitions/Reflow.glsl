// Author: gre
// License: MIT
// Description: The outgoing image behaves like a paragraph in a text box that narrows from the right: thin gaps open between its lines and each row wraps its end onto the next line, while beside it the incoming image grows from fragments of its own top rows and unwraps back into one image as its box widens to the full frame
// Tags: text, lines, stripes, paper, wipe, graphic

// @range(3, 16, 1) Number of lines
uniform int lines; // = 7
// @color Paper seen between the lines and the boxes
uniform vec4 paper; // = vec4(0.96, 0.95, 0.92, 1.0)

const float EDGE = 0.002;

float ease(float x) {
  return x < 0.5 ? 4.0 * x * x * x : 1.0 - 4.0 * (1.0 - x) * (1.0 - x) * (1.0 - x);
}

// one image laid out as a stream of rows in a box [x0, x0 + w]; a narrow space separates its rows like words
vec4 box(vec2 uv, float x0, float w, float env, bool incoming) {
  float n = max(float(lines), 1.0);
  float row = (1.0 - uv.y) * n;
  float line = floor(row);
  float yin = row - line;
  float space = 0.04 * env;
  float q = line * w + clamp(uv.x - x0, 0.0, w);
  float src = floor(q / (1.0 + space));
  float xin = q - src * (1.0 + space);
  // the second half of a space antialiases the start of the next row
  if (xin > 1.0 + 0.5 * space) {
    src += 1.0;
    xin -= 1.0 + space;
  }
  vec2 s = vec2(clamp(xin, 0.0, 1.0), 1.0 - (src + yin) / n);
  vec4 c = incoming ? getToColor(s) : getFromColor(s);
  float lead = 0.06 * env;
  float d = min(yin, 1.0 - yin);
  // masks are offset by one edge width so they stay exactly 1 where a gap has zero width
  float ink = clamp((d - lead) / (EDGE * n) + 1.0, 0.0, 1.0);
  ink *= clamp(min(xin, 1.0 - xin) / EDGE + 1.0, 0.0, 1.0);
  float inBox = clamp(min(uv.x - x0, x0 + w - uv.x) / EDGE + 1.0, 0.0, 1.0);
  ink *= inBox;
  c.rgb *= 1.0 - 0.2 * env * (1.0 - smoothstep(0.0, 0.2, d));
  // each line casts a short shadow on the paper just below it
  float below = yin < 0.5 ? yin + lead : yin - (1.0 - lead);
  vec4 bg = paper;
  bg.rgb *= 1.0 - 0.3 * env * inBox * step(0.0, below) * step(0.5, row) * exp(-below / 0.04);
  return mix(bg, c, ink);
}

vec4 transition(vec2 uv) {
  float w = 1.0 - ease(progress);
  float env = 4.0 * w * (1.0 - w);
  float g = 0.012 * env;
  return uv.x < w ? box(uv, 0.0, w - g, env, false) : box(uv, w + g, 1.0 - w - g, env, true);
}
