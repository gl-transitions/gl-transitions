// Author: gre
// License: MIT
// Description: The incoming image is rebuilt as a stack of cut paper sheets, one per band of brightness: from the darkest to the lightest, each sheet slides in lifted above the stack, drops into place with a soft shadow on the sheets below, then the paper flattens into the photo
// Tags: paper, layers, cut, shadow, stylized

// @range(2, 8, 1) Number of paper sheets, one per band of brightness of the incoming image
uniform int layers; // = 5
// @range(0, 1) How much of the incoming image's colors the paper takes: 0 is plain paper in shades of the paper color
uniform float colorful; // = 0.7
// @range(0, 1) Darkness of the shadows the sheets cast on the ones below
uniform float shadow; // = 0.6
// @color Color of the lightest sheet of paper, the darker ones are shades of it
uniform vec4 paper; // = vec4(0.97, 0.94, 0.88, 1.0)

const float MAX_LAYERS = 8.0;
// part of the progress at which the last sheet lands, and longest duration of the slide of one sheet
const float STACKED = 0.74;
const float SLIDE = 0.2;
// height a sheet falls from, as the extra distance its shadow is cast at
const float LIFT = 3.0;
// shadow offset of a sheet lying on the stack, in frame heights, toward the bottom right
const vec2 SHADOW = vec2(0.012, -0.018);
// softness of the cut edges and of the shadows' edges, in brightness
const float CUT = 0.012;
const float SHADOW_CUT = 0.05;
// radius over which the brightness is softened before it is cut, so that the cuts follow smooth curves,
// and the wider one for the shadows, in frame heights
const float BLUR = 0.004;
const float SHADOW_BLUR = 0.01;
// width of the anti-aliased leading edge of a sliding sheet, in frame heights
const float EDGE = 0.0015;

float luma(vec4 c) {
  return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

float plHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// paper fibers: a faint value noise moving with the sheet
float grain(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(plHash(i), plHash(i + vec2(1.0, 0.0)), f.x),
    mix(plHash(i + vec2(0.0, 1.0)), plHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// mirrored coordinates, so that a shifted lookup never smears the frame's border
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// brightness of the incoming image at p (whose color is c) softened over a disc of the given radius in frame heights
float softLuma(vec2 p, vec4 c, float radius, vec2 aspect) {
  vec2 r = radius / aspect;
  float l = luma(c);
  l += luma(getToColor(mirror(p + r * vec2(0.0, 1.0))));
  l += luma(getToColor(mirror(p + r * vec2(0.866, -0.5))));
  l += luma(getToColor(mirror(p + r * vec2(-0.866, -0.5))));
  return l / 4.0;
}

// coverage of sheet k of n: the whole frame for the first one, else where the softened brightness l reaches its threshold
float cut(float k, float n, float l, float soft) {
  if (k < 0.5) return 1.0;
  float thr = k / n;
  return smoothstep(thr - soft, thr + soft, l);
}

vec4 transition(vec2 uv) {
  float n = clamp(float(layers), 2.0, MAX_LAYERS);
  float sh = clamp(shadow, 0.0, 1.0);
  vec2 aspect = vec2(ratio, 1.0);
  vec2 shadowOffset = SHADOW / aspect;
  // the paper flattens into the photo once the last sheet is about to land
  float toPhoto = smoothstep(STACKED - 0.03, 1.0, progress);

  // the incoming image where the sheets lie on the stack, and where they cast their shadow
  // (only looked up once the first sheet has landed)
  vec4 rest = getToColor(uv);
  float restLuma = 0.0;
  vec4 restShadowColor = vec4(0.0);
  float restShadow = 0.0;
  float n1 = n - 1.0;
  // duration of the slide of one sheet, short enough that at most two sheets slide at once
  float slide = min(SLIDE, 2.0 * STACKED / (n1 + 2.0));
  float spacing = (STACKED - slide) / n1;
  if (progress >= slide) {
    restLuma = softLuma(uv, rest, BLUR, aspect);
    vec2 ps = uv - shadowOffset;
    restShadowColor = getToColor(mirror(ps));
    restShadow = softLuma(ps, restShadowColor, SHADOW_BLUR, aspect);
  }

  vec4 color = getFromColor(uv);
  for (float k = 0.0; k < MAX_LAYERS; k += 1.0) {
    if (k < n) {
      float t = clamp((progress - k * spacing) / slide, 0.0, 1.0);
      if (t > 0.0) {
        // eased slide from above the frame, the sheet still lifted (and seen bigger) until it lands
        float e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
        float lift = 1.0 - smoothstep(0.5, 1.0, t);
        vec2 q = (uv - 0.5) / (1.0 + 0.03 * lift) + 0.5;
        q.y -= (1.0 - e) * 1.15;
        vec2 so = shadowOffset * (1.0 + LIFT * lift);
        vec4 src = rest;
        float l = restLuma;
        float ls = restShadow;
        float shadowAlpha = restShadowColor.a;
        if (t < 1.0) {
          src = getToColor(mirror(q));
          l = softLuma(q, src, BLUR, aspect);
          vec4 cs = getToColor(mirror(q - so));
          ls = softLuma(q - so, cs, SHADOW_BLUR, aspect);
          shadowAlpha = cs.a;
        }
        // the sheet ends at its bottom edge (its leading edge) while it slides in
        float m = cut(k, n, l, CUT) * src.a * smoothstep(-EDGE, EDGE, q.y);
        float s = cut(k, n, ls, SHADOW_CUT) * shadowAlpha * smoothstep(-EDGE, EDGE, q.y - so.y);
        // shadow on what lies below, lighter while the sheet is lifted
        color.rgb *= 1.0 - sh * (1.0 - toPhoto) * (0.7 - 0.35 * lift) * s * (1.0 - m);
        // the sheet's color: a shade of paper for its band of brightness, tinted by the photo
        // (the dark bands are lifted a little, as paper is never black)
        float level = 0.25 + 0.75 * k / n1;
        vec3 plain = paper.rgb * level;
        vec3 tinted = clamp(level + 1.25 * (src.rgb - luma(src)), 0.0, 1.0);
        vec3 sheet = mix(plain, tinted, 0.9 * clamp(colorful, 0.0, 1.0));
        sheet *= 0.975 + 0.05 * grain(q * aspect * 160.0 + k * 37.0);
        color = mix(color, vec4(sheet, paper.a), m);
      }
    }
  }
  return mix(color, rest, toPhoto);
}
