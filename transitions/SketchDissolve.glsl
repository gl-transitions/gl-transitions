// Author: gre
// License: MIT
// Description: The outgoing image fades back to blank paper while the incoming one is drawn on it in pencil, outlines first and then hatching in the shadows, before its shading and colors fill in until the picture is complete
// Tags: pencil, drawing, sketch, edges, dissolve

// @range(0.5, 4) Thickness of the pencil outlines, in thousandths of the frame height
uniform float lineWidth; // = 1.5
// @range(0, 2) How many outlines are drawn: higher also traces the fainter edges of the picture
uniform float edges; // = 1.0
// @range(0, 1) Amount of diagonal hatching drawn in the shadows
uniform float hatching; // = 0.6
// @color Color of the paper
uniform vec4 paper; // = vec4(0.96, 0.94, 0.89, 1.0)
// @color Color of the pencil
uniform vec4 ink; // = vec4(0.16, 0.16, 0.2, 1.0)

float sdHash (vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float sdNoise (vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(sdHash(i), sdHash(i + vec2(1.0, 0.0)), f.x),
    mix(sdHash(i + vec2(0.0, 1.0)), sdHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// luma and alpha of the incoming image: outlines follow both
vec2 sdTone (vec2 uv) {
  vec4 c = getToColor(uv);
  return vec2(dot(c.rgb, vec3(0.299, 0.587, 0.114)), c.a);
}

// one family of hatching strokes along direction d, as thick as the shadow is dark
float sdHatch (vec2 q, vec2 d, float dark) {
  float s = dot(q, d) * 60.0 + 0.5 * sdNoise(q * 9.0 + d * 13.0);
  float row = floor(s);
  // each row is made of strokes of uneven length and pressure, with small gaps
  float along = dot(q, vec2(-d.y, d.x)) * 8.0 + sdHash(vec2(row, d.y * 7.0)) * 5.0;
  float cell = floor(along);
  float k = sdHash(vec2(row, cell) + d * 31.0);
  float gap = smoothstep(0.0, 0.12, fract(along)) * (1.0 - smoothstep(0.75 - 0.2 * k, 1.0, fract(along)));
  float w = 0.5 * clamp(dark, 0.0, 1.0) * (0.7 + 0.3 * k);
  return (1.0 - smoothstep(w - 0.24, w, abs(fract(s) - 0.5))) * gap * (0.6 + 0.4 * k);
}

vec4 transition (vec2 uv) {
  vec2 q = vec2(uv.x * ratio, uv.y);
  // a slightly wobbly hand: the outlines are traced a bit off the real edges
  vec2 wob = (vec2(sdNoise(q * 6.0), sdNoise(q * 6.0 + 17.0)) - 0.5) * 0.004;
  vec2 su = uv + wob * (1.0 - progress);
  vec2 dx = vec2(0.001 * lineWidth / ratio, 0.0);
  vec2 dy = vec2(0.0, 0.001 * lineWidth);
  vec2 tl = sdTone(su - dx + dy), tm = sdTone(su + dy), tr = sdTone(su + dx + dy);
  vec2 ml = sdTone(su - dx), mr = sdTone(su + dx);
  vec2 bl = sdTone(su - dx - dy), bm = sdTone(su - dy), br = sdTone(su + dx - dy);
  vec2 gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
  vec2 gy = (tl + 2.0 * tm + tr) - (bl + 2.0 * bm + br);
  float g = max(length(vec2(gx.x, gy.x)), length(vec2(gx.y, gy.y))) * max(edges, 0.0);
  float outline = smoothstep(0.12, 0.5, g);
  vec4 toC = getToColor(uv);
  float l = clamp((tm.x + bm.x + ml.x + mr.x) * 0.25, 0.0, 1.0);

  // graphite grain, and the order in which the strokes are laid down
  float grain = 0.65 + 0.35 * sdNoise(q * vec2(180.0, 60.0));
  float order = sdNoise(q * 3.0 + 4.0);
  float fine = sdNoise(q * 24.0);
  float drawOutline = smoothstep(0.0, 0.1, progress - (0.22 * order + 0.05 * fine));
  float drawHatch = smoothstep(0.0, 0.12, progress - (0.2 + 0.2 * order + 0.05 * fine));

  // the shading builds up from the darkest parts to the lightest, then the colors come in
  float fill = smoothstep(0.0, 0.22, progress - (0.4 + 0.25 * l + 0.1 * order));

  // hatching: one direction in the shadows, crossed in the darkest parts
  float dark = 1.0 - l;
  float h1 = sdHatch(q, vec2(0.7071, 0.7071), smoothstep(0.35, 0.9, dark));
  float h2 = sdHatch(q, vec2(0.7071, -0.7071), smoothstep(0.65, 1.0, dark));
  float hatch = hatching * 0.8 * max(h1, 0.8 * h2) * toC.a;

  // the hatching is absorbed by the shading as it fills in
  hatch *= drawHatch * (1.0 - 0.6 * fill);
  float pencil = max(outline * drawOutline, hatch) * grain;
  // the pencil lines give way to the finished picture at the end
  pencil *= 1.0 - smoothstep(0.7, 1.0, progress);

  // the outgoing image fades back to paper
  vec4 base = mix(getFromColor(uv), paper, smoothstep(0.02, 0.38, progress));
  float sat = smoothstep(0.55, 1.0, progress);
  vec4 tone = vec4(paper.rgb * mix(0.3, 1.0, l), paper.a * toC.a);
  vec4 col = mix(tone, toC, sat);
  base = mix(base, col, fill);
  return mix(base, ink, pencil);
}
