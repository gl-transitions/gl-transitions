// Author: hong
// License: MIT
// Description: The right half of the outgoing image is a book page that turns over from right to left on the spine at the middle of the frame, curling near its free edge, its back bringing the left half of the incoming image
// Tags: page, flip, 3d

// @range(0, 1) Strength of the perspective: the page grows as it lifts toward the viewer
uniform float perspective; // = 0.5
// @range(0, 1) How much the page darkens as it turns away from the light, and the shadows it casts
uniform float shading; // = 0.6
// @range(0, 1) How much the page bends near its free edge, which trails behind as it turns
uniform float curl; // = 0.5

const float PI = 3.141592653589793;
// width of the anti-aliased edges, as a part of the frame's height
const float EDGE = 0.0015;
// part of the page's width that curls
const float CURL_PART = 0.45;
// direction of the light, in (x, height toward the viewer)
const vec2 LIGHT = vec2(-0.447214, 0.894427);

float cross2(vec2 a, vec2 b) {
  return a.x * b.y - a.y * b.x;
}

// the page's angle, 0 lying on the right to PI lying on the left: eased, but never at rest
float pageAngle() {
  float p = clamp(progress, 0.0, 1.0);
  return PI * p * (0.35 + p * (1.95 - 1.3 * p));
}

// The page is seen in a cross-section across the spine, in (x, height toward the viewer) from the spine:
// a straight part at angle a from the spine, then, when k is not 0, an arc of curvature k centered on c up to its free edge,
// extruded along y. Returns the nearest point of the page hit by the ray from eye along dir:
// (ray length, distance along the page, angle there), with a negative ray length when it is missed.
vec3 hitPage(vec2 eye, vec2 dir, float a, float k, float straight, vec2 c, float w) {
  vec3 best = vec3(-1.0, 0.0, 0.0);
  vec2 d = vec2(cos(a), sin(a));
  // the straight part
  float den = cross2(d, dir);
  if (abs(den) > 1e-7) {
    float u = cross2(eye, dir) / den;
    float t = cross2(eye, d) / den;
    if (t > 0.0 && u >= 0.0 && u <= straight) best = vec3(t, u, a);
  }
  if (k != 0.0) {
    float r = 1.0 / k;
    vec2 oc = eye - c;
    float qa = dot(dir, dir);
    float qb = dot(oc, dir);
    float disc = qb * qb - qa * (dot(oc, oc) - r * r);
    if (disc >= 0.0) {
      float sq = sqrt(disc);
      for (int i = 0; i < 2; i++) {
        float t = (-qb + (i == 0 ? -sq : sq)) / qa;
        if (t > 0.0 && (best.x < 0.0 || t < best.x)) {
          // (sin(b), -cos(b)) where b is the angle of the page at that point
          vec2 v = (oc + t * dir) * k;
          float db = atan(v.x, -v.y) - a;
          db -= 2.0 * PI * floor((db + PI) / (2.0 * PI));
          float s = db / k;
          if (s >= 0.0 && s <= w - straight) best = vec3(t, straight + s, a + db);
        }
      }
    }
  }
  return best;
}

// the point of the curled part of the page where its angle is b
vec2 curlPoint(vec2 c, float k, float b) {
  return c + vec2(sin(b), -cos(b)) / k;
}

vec4 transition (vec2 uv) {
  float a = pageAngle();
  float lift = sin(a);
  // half the frame's width: the page's width
  float w = 0.5 * ratio;
  float x = uv.x * ratio - w;
  // the viewer is above the spine, the page lifting toward it
  float dist = w * (1.0 + 1.5 / max(perspective, 0.01));
  vec2 eye = vec2(0.0, dist);
  vec2 dir = vec2(x, -dist);

  // the shape of the page: straight, then curled with its free edge trailing behind (a negative curvature)
  vec2 d = vec2(cos(a), sin(a));
  float k = -clamp(curl, 0.0, 1.0) * lift / (CURL_PART * w);
  if (abs(k) * CURL_PART * w <= 1e-4) k = 0.0;
  float straight = k != 0.0 ? (1.0 - CURL_PART) * w : w;
  vec2 c = straight * d + vec2(-d.y, d.x) / (k != 0.0 ? k : 1.0);
  vec2 bend = straight * d;
  vec2 middle = k != 0.0 ? curlPoint(c, k, a + 0.5 * k * (w - straight)) : bend;
  vec2 edge = k != 0.0 ? curlPoint(c, k, a + k * (w - straight)) : bend;

  // anti-aliased edges, only once the page has left the frame's plane, so that it covers it exactly at both ends
  float aa = EDGE * min(20.0 * lift, 1.0);
  vec4 img = vec4(0.0);
  float m = 0.0;
  vec3 hit = hitPage(eye, dir, a, k, straight, c, w);
  if (hit.x > 0.0) {
    float t = hit.x;
    float u = hit.y;
    float b = hit.z;
    vec2 pt = eye + t * dir;
    // the height on the page, magnified as it comes closer (its top and bottom edges are out of the frame)
    float y = clamp(0.5 + (uv.y - 0.5) * t, 0.0, 1.0);
    // near its free edge, the distance to it on the screen
    float edgeX = edge.x * dist / max(dist - edge.y, 1e-4);
    m = aa > 0.0 && u > (k != 0.0 ? straight : 0.5 * w) ? clamp(abs(x - edgeX) / aa, 0.0, 1.0) : 1.0;
    vec2 normal = vec2(-sin(b), cos(b));
    bool front = dot(normal, eye - pt) > 0.0;
    img = front
      ? getFromColor(vec2(clamp(w + u, w, ratio) / ratio, y))
      : getToColor(vec2(clamp(w - u, 0.0, w) / ratio, y));
    // lit from the upper left: brighter as it turns toward the light, darker as it turns away, with a soft crease along the spine
    float diffuse = max(dot(front ? normal : -normal, LIGHT), 0.0) / LIGHT.y;
    float shade = mix(1.0, 0.25 + 0.75 * diffuse, shading);
    shade *= 1.0 - 0.35 * shading * lift * exp(-u / (0.04 * w));
    img.rgb *= shade;
    if (m >= 1.0) return img;
  }

  // the pages beneath: the outgoing image on the left, the incoming one on the right
  vec4 color = x < 0.0 ? getFromColor(uv) : getToColor(uv);
  // the lifted page shades them, the more it hides of the sky (and so the more near the spine and its free edge)
  vec2 toEdge = edge - vec2(x, 0.0);
  float cosEdge = toEdge.x / max(length(toEdge), 1e-6);
  float blocked = 0.5 * abs((x < 0.0 ? 1.0 : -1.0) - cosEdge);
  float shadow = blocked * blocked * (3.0 - 2.0 * blocked);
  // and casts a shadow, the light coming from the upper left, softer as the page is higher
  float slope = -LIGHT.x / LIGHT.y;
  vec3 reach = vec3(bend.x, middle.x, edge.x) + slope * vec3(bend.y, middle.y, edge.y);
  float lo = min(0.0, min(reach.x, min(reach.y, reach.z)));
  float hi = max(0.0, max(reach.x, max(reach.y, reach.z)));
  float soft = max(0.25 * edge.y, 1e-5);
  shadow = max(0.5 * shadow, 0.85 * clamp(min(x - lo, hi - x) / soft + 0.5, 0.0, 1.0) * min(4.0 * lift, 1.0));
  color.rgb *= 1.0 - shading * shadow;
  return mix(color, img, m);
}
