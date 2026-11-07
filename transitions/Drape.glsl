// Author: gre
// License: MIT
// Description: The outgoing image hangs like a sheet of fabric that is let go at the top: its top edge drops and buckles into soft shaded folds as the cloth collapses and slides down out of the frame, revealing the incoming image behind it
// Tags: fabric, fold, vertical, 3d, shadow

// @range(1, 16, 1) Number of folds across the cloth (fewer in a portrait image)
uniform float folds; // = 6.0
// @range(0, 1) Depth of the folds and of their shading
uniform float depth; // = 0.7
// @range(0, 1) How much the cloth sways sideways as it falls
uniform float sway; // = 0.4
// @range(0, 1) Strength of the soft shadow cast by the cloth on the incoming image
uniform float shadow; // = 0.5

const float PI = 3.141592653589793;

// folds a coordinate back into 0..1, mirroring the image at its edges
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition (vec2 uv) {
  float t = progress;
  // the top edge falls first and the hem follows later: the cloth collapses as it slides down
  float top = 1.0 - 1.02 * t * (0.35 + 0.65 * t);
  float bottom = -0.75 * t * t * t;
  // the folds form as soon as the top is let go
  float f = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
  float g = depth * f;
  float n = max(1.0, floor(folds * min(ratio, 1.0) + 0.5));
  float k = 2.0 * PI * n;
  // the cloth swings a little sideways (xs: position across the cloth, 0 to 1)
  float xs = uv.x - sway * 0.05 * sin(2.0 * PI * t) * f;
  // the top edge sags in the middle and buckles with the folds
  float c = 2.0 * xs - 1.0;
  float sag = 0.1 * sin(PI * t) * (1.0 - c * c);
  float a = k * xs;
  float b = a + 0.8 * sin(0.5 * a + 1.7); // uneven folds
  float ripple = sin(2.0 * b + 0.9); // smaller folds between the big ones
  float hem = top - sag - g * (0.04 * (0.5 + 0.5 * sin(b)) + 0.012 * ripple);
  // distance to the outline of the cloth, negative inside
  float outside = max(uv.y - hem, max(-xs, xs - 1.0));
  // anti-aliased outline, sharp at rest so the first frame is exact
  float aa = 0.003 * f;
  float cover = aa > 0.0 ? clamp(-outside / aa, 0.0, 1.0) : step(outside, 0.0);
  vec4 cloth = vec4(0.0);
  if (cover > 0.0) {
    float h = max(hem - bottom, 1e-4);
    float s = clamp((uv.y - bottom) / h, 0.0, 1.0); // height on the cloth, 0 at the hem, 1 at the top edge
    float s2 = s * s;
    // the folds start at the buckled top edge and fan out, fading toward the hem
    float bf = b - k * (xs - 0.5) * 0.25 * g * (1.0 - s);
    float amp = g * (0.3 + 0.7 * s2);
    // the fabric is pushed together under the top edge
    float comp = 1.0 - h; // how much the cloth is shortened
    float v = s * h + comp * s2 * s;
    float u = xs + 0.65 * amp * sin(bf) / k; // gathered in the folds, never folding back on itself
    vec4 col = getFromColor(mirror(vec2(u, v)));
    // fold normal, lit from the front and a little from above and the left
    float dzdx = amp * (3.2 * cos(bf) * (1.0 + 0.4 * cos(0.5 * a + 1.7)) + 1.1 * s2 * cos(2.0 * bf + 0.9));
    float dzdy = 1.6 * g * s * sin(bf) - 0.8 * comp * s2;
    vec3 nrm = normalize(vec3(-dzdx, -dzdy, 1.0));
    vec3 light = normalize(vec3(-0.35, 0.3, 1.0));
    float diffuse = max(dot(nrm, light), 0.0) / light.z; // 1 on a flat cloth
    // the hollows of the folds and the rolled top edge get less light
    float hollow = 0.5 - 0.5 * sin(bf);
    hollow *= hollow * (0.3 + 0.7 * s);
    float rim = exp((uv.y - hem) * 90.0);
    float shade = mix(1.0, diffuse * (1.0 - 0.6 * hollow) * (1.0 - 0.35 * rim), g);
    cloth = vec4(col.rgb * shade, col.a);
    if (cover >= 1.0) return cloth;
  }
  // soft shadow of the cloth, held a little away from the incoming image, gone once it has left
  vec4 to = getToColor(uv);
  float sh = shadow * exp(-max(outside, 0.0) * 16.0) * f * clamp(8.0 * (1.0 - t), 0.0, 1.0);
  return mix(vec4(to.rgb * (1.0 - 0.8 * sh), to.a), cloth, cover);
}
