// Author: gre
// License: MIT
// Description: A bright blade stroke slashes diagonally across the outgoing image with a flash, then the two cut halves slip along the cut in opposite directions and fly off the frame, casting soft shadows on the incoming image beneath
// Tags: split, slide, flash, shadow

// @range(-75, 75) Angle of the cut against the horizontal, in degrees
uniform float angle; // = 25.0
// @range(0, 0.3) How far the halves move apart across the cut as they slide, relative to the image height
uniform float separation; // = 0.06
// @color Color of the blade stroke and its flash (alpha sets the intensity)
uniform vec4 flash; // = vec4(1.0, 0.96, 0.88, 1.0)
// @color Color of the shadow cast on the incoming image
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.45)

// part of the transition during which the blade crosses the frame
const float CUT = 0.18;
// width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0015;
// offset and softness of the shadows, as a part of the frame's height
const vec2 SHADOW_OFFSET = vec2(0.015, -0.022);
const float SHADOW_BLUR = 0.035;

// signed distance (aspect units) to the frame rectangle centered on 0, negative inside
float boxDistance (vec2 q) {
  vec2 d = abs(q) - 0.5 * vec2(ratio, 1.0);
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// one half of the outgoing image, moved by v; s = 1 for the half above the cut, -1 below
// returns the image point of screen point q (xy) and a signed distance to the half (z, negative inside);
// the half overhangs its edges by half an edge width so that the still image covers the frame exactly
vec3 piece (vec2 q, vec2 v, vec2 n, float s) {
  vec2 y = q - v;
  return vec3(y, max(boxDistance(y), -s * dot(y, n)) - 0.5 * EDGE);
}

vec4 transition (vec2 uv) {
  float p = progress;
  float a = radians(angle);
  vec2 T = vec2(cos(a), sin(a));
  vec2 N = vec2(-T.y, T.x);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  float d = dot(q, N);
  float along = dot(q, T);

  // the halves: a quick snap apart across the cut, then an accelerating slide along it
  float t = clamp((p - 0.8 * CUT) / (1.0 - 0.8 * CUT), 0.0, 1.0);
  float open = separation * (1.0 - pow(1.0 - t, 3.0));
  // far enough along the cut for each half to leave the frame with its shadow
  float margin = length(SHADOW_OFFSET) + SHADOW_BLUR + 2.0 * EDGE;
  float exitX = (ratio + separation + margin) / max(abs(T.x), 1e-3);
  float exitY = (1.0 + separation + margin) / max(abs(T.y), 1e-3);
  float slide = min(exitX, exitY) * t * t * (1.5 - 0.5 * t);
  vec2 vUp = T * slide + N * open;

  // the incoming image with the shadows of both halves
  vec4 to = getToColor(uv);
  vec2 sq = q - SHADOW_OFFSET;
  float sdUp = piece(sq, vUp, N, 1.0).z;
  float sdDown = piece(sq, -vUp, N, -1.0).z;
  float sh = shadow.a * smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(-0.5 * SHADOW_BLUR, SHADOW_BLUR, min(sdUp, sdDown)));
  vec4 c = vec4(mix(to.rgb, shadow.rgb, sh), to.a);

  // the blade: its head crosses the frame along the cut
  float reach = 0.5 * length(vec2(ratio, 1.0)) + 0.1;
  float k = clamp(p / CUT, 0.0, 1.0);
  float head = mix(-reach, reach, 1.0 - (1.0 - k) * (1.0 - k));
  float behind = head - along;
  float drawn = clamp(0.5 + behind / EDGE, 0.0, 1.0);

  // the halves, their cut edges catching the light of the blade behind its head
  float rim = flash.a * smoothstep(0.0, CUT, p) * (1.0 - 0.6 * t) * drawn;
  for (int i = 0; i < 2; i++) {
    float s = i == 0 ? 1.0 : -1.0;
    vec3 h = piece(q, s * vUp, N, s);
    float cover = clamp(0.5 - h.z / EDGE, 0.0, 1.0);
    vec4 col = getFromColor(clamp(h.xy / vec2(ratio, 1.0) + 0.5, 0.0, 1.0));
    float e = max(s * dot(h.xy, N), 0.0);
    col.rgb = mix(col.rgb, flash.rgb, rim * exp(-e / 0.004) * col.a);
    c = mix(c, col, cover);
  }

  // the blade stroke: a thin streak behind the head, which lingers and fades
  float tail = drawn * (0.35 + 0.65 * exp(-max(behind, 0.0) * 4.0));
  float env = smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(CUT, CUT + 0.12, p));
  float core = exp(-abs(d) / 0.0025) + 0.35 * exp(-abs(d) / 0.02);
  float spark = exp(-length(vec2(behind, d)) / 0.03) * (1.0 - k);
  float glow = flash.a * env * (core * tail + spark);
  // a short flash of the whole frame as the blade leaves it
  float burst = flash.a * 0.25 * smoothstep(0.6 * CUT, CUT, p) * (1.0 - smoothstep(CUT, CUT + 0.15, p));
  c.rgb = mix(c.rgb, flash.rgb, burst * c.a);
  c.rgb += flash.rgb * glow * c.a;
  return c;
}
