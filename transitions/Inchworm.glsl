// Author: gre
// License: MIT
// Description: The outgoing image crawls out of the frame like an inchworm: its back edge creeps forward and the picture humps up into a tall shaded arch, then its front edge reaches ahead and the arch flattens, two strides, uncovering the incoming image behind
// Tags: crawl, hump, 3d, shadow, directional, organic

// @range(0.5, 1.5) How tall the arch grows toward the viewer
uniform float arch; // = 1.0

const float PI = 3.14159265;
const float STRIDE = 0.5;
const float AA = 0.002;
const vec3 LIGHT = vec3(-0.5847, 0.3118, 0.7484);

float iwEase(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

float iwHump(float x, float a, float span, float h) {
  float u = clamp((x - a) / span, 0.0, 1.0);
  float s = sin(PI * pow(u, 0.8));
  return h * s * s;
}

vec4 transition(vec2 uv) {
  float t = progress * 3.0;
  // overlapping beats keep the crawl flowing: gather, reach, gather
  float g = iwEase(t / 1.2) + iwEase((t - 1.8) / 1.2);
  float reach = iwEase((t - 0.8) / 1.4);
  // two gathers carry the back edge just past the right side of the frame, whatever its width
  float a = STRIDE * g * ratio + 0.003 * g;
  float span = (1.0 + STRIDE * reach) * ratio - a;
  // follows the sheet's length, eased off on wide frames so the arch never nears the eye
  float h = arch * 0.55 * (ratio - span) * sqrt((ratio + span) / ratio);
  h = min(h / (1.0 + 0.5 * h), 1.2);

  // seen from slightly below, so the raised arch lifts its bottom edge off the floor
  vec3 eye = vec3(0.5 * ratio, -1.0, 1.8);
  vec3 ray = vec3(uv.x * ratio, uv.y, 0.0) - eye;

  float s0 = 1.0 - (h + 0.001) / eye.z;
  float sl = s0;
  float fl = eye.z * (1.0 - s0) - iwHump(eye.x + s0 * ray.x, a, span, h);
  float sr = 1.0;
  int side = 0;
  for (int i = 1; i <= 40; i++) {
    float s = mix(s0, 1.0, float(i) / 40.0);
    float f = eye.z * (1.0 - s) - iwHump(eye.x + s * ray.x, a, span, h);
    float y = eye.y + s * ray.y;
    if ((fl > 0.0) != (f > 0.0) && y > -2.0 * AA && y < 1.0 + 2.0 * AA) {
      sr = s;
      side = fl > 0.0 ? 1 : 2;
      break;
    }
    sl = s;
    fl = f;
  }
  float fr = eye.z * (1.0 - sr) - iwHump(eye.x + sr * ray.x, a, span, h);
  for (int i = 0; i < 5; i++) {
    float sm = 0.5 * (sl + sr);
    float fm = eye.z * (1.0 - sm) - iwHump(eye.x + sm * ray.x, a, span, h);
    if ((fm > 0.0) == (fl > 0.0)) {
      sl = sm;
      fl = fm;
    } else {
      sr = sm;
      fr = fm;
    }
  }
  // a final secant step lands exactly on the floor where the sheet lies flat
  float sh = abs(fl - fr) > 1e-6 ? sl + (sr - sl) * fl / (fl - fr) : sr;
  vec3 hit = eye + sh * ray;

  float len = 0.0;
  float tot = 0.0;
  float prev = 0.0;
  for (int i = 1; i <= 24; i++) {
    float x = a + span * float(i) / 24.0;
    float z = iwHump(x, a, span, h);
    float seg = sqrt(span * span / 576.0 + (z - prev) * (z - prev));
    tot += seg;
    len += seg * clamp((hit.x - x) * 24.0 / span + 1.0, 0.0, 1.0);
    prev = z;
  }

  float e = 0.002 * ratio;
  float dz = (iwHump(hit.x + e, a, span, h) - iwHump(hit.x - e, a, span, h)) / (2.0 * e);
  vec3 n = normalize(vec3(-dz, 0.0, 1.0));
  float light = (0.45 + 0.55 * max(dot(n, LIGHT), 0.0)) / (0.45 + 0.55 * LIGHT.z);
  // the underside of the arch only gets light bounced off the floor
  light = side == 2 ? 0.35 : light;
  vec4 sheet = getFromColor(vec2(len / max(tot, 1e-6), clamp(hit.y, 0.0, 1.0)));
  sheet.rgb *= light;
  float cov = side > 0 ? smoothstep(-2.0 * AA, 0.0, hit.y) * smoothstep(-2.0 * AA, 0.0, 1.0 - hit.y) * smoothstep(a - 2.0 * AA, a, hit.x) : 0.0;

  float occ = 0.0;
  for (int i = 1; i <= 8; i++) {
    float z = h * float(i) / 8.0;
    float x = uv.x * ratio + z * LIGHT.x / LIGHT.z;
    float y = uv.y + z * LIGHT.y / LIGHT.z;
    float inside = smoothstep(-0.02, 0.0, y) * smoothstep(-0.02, 0.0, 1.0 - y);
    occ = max(occ, inside * smoothstep(0.0, 0.04, iwHump(x, a, span, h) - z));
  }
  vec4 floorColor = getToColor(uv);
  float ao = smoothstep(0.0, 0.3, iwHump(uv.x * ratio, a, span, h));
  floorColor.rgb *= (1.0 - 0.5 * occ) * (1.0 - 0.3 * ao);

  return mix(floorColor, sheet, cov);
}
