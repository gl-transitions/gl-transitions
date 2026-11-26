// Author: gre
// License: MIT
// Description: The outgoing image becomes a shimmering tinsel curtain of thin vertical strands swung by a breeze; each strand twists half a turn on its own, glinting as it turns edge-on, the twist climbing from the bottom ends to the top, until every strand shows the incoming image on its back
// Tags: tinsel, curtain, strands, twist, sparkle, party

// @range(40.0, 300.0) Number of strands across the frame
uniform float strands; // = 90.0
// @range(0.0, 1.0) How far the breeze swings the strands
uniform float sway; // = 0.5
// @color Color of the glints on the crinkled strands
uniform vec4 glintColor; // = vec4(1.0, 0.95, 0.85, 1.0)

const float PI = 3.141592653589793;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec4 transition(vec2 uv) {
  float env = sin(PI * progress);
  float drop = 1.0 - uv.y;
  float swing = sway * 0.04 * env * drop * drop * sin(uv.x * 9.0 - progress * 14.0 + uv.y * 2.0);
  float x = uv.x + swing / ratio;
  float n = strands;
  float i = floor(x * n);
  float u = fract(x * n) - 0.5;
  float h = hash12(vec2(i, 3.0));
  // the breeze reaches the free bottom ends first, and the twist climbs each strand
  float t = clamp((progress - 0.3 * h - 0.3 * uv.y) / 0.38, 0.0, 1.0);
  // the width cos(theta) shrinks linearly so the turn shows from its first frame to its last
  float c = 1.0 - 2.0 * t;
  float w = max(abs(c), 0.02);
  float px = 1.2 * n / (ratio * 900.0);
  float face = clamp((0.5 * w - abs(u)) / px + 1.0, 0.0, 1.0);
  vec2 suv = vec2((i + 0.5 + u / w) / n - swing / ratio, uv.y);
  suv.x = 1.0 - abs(1.0 - mod(suv.x, 2.0));
  vec4 col = c > 0.0 ? getFromColor(suv) : getToColor(suv);
  float s2 = 1.0 - c * c;
  float crinkle = hash12(vec2(i, floor(uv.y * 90.0 + h * 40.0)));
  float shade = 1.0 - 0.45 * s2 * (1.0 - abs(c)) + 0.25 * s2 * (crinkle - 0.5);
  float glint = s2 * pow(crinkle, 12.0) * 2.5 * (1.0 - smoothstep(0.0, 0.3, abs(u) / w - 0.2));
  col.rgb = col.rgb * shade + glint * glintColor.rgb * glintColor.a;
  vec4 behind = mix(getFromColor(uv), getToColor(uv), smoothstep(0.35, 0.65, progress));
  behind.rgb *= 0.3;
  return mix(behind, col, face);
}
