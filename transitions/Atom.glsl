// Author: gre
// License: MIT
// Description: A nucleus of the incoming picture appears in the middle of the outgoing one and three glowing electrons race around it on crossed elliptical orbits, each laying a ribbon of the incoming picture with a bright rim; the atom turns and grows while its ribbons and nucleus swell until they fill the frame
// Tags: shape, light, rotate, abstract, reveal

// @range(1.1, 3) Laps each electron runs around its orbit
uniform float laps; // = 1.75
// @range(0.15, 0.6) Width of an orbit's minor axis relative to its major axis
uniform float flatness; // = 0.34
// @color Color of the rims of the ribbons and nucleus
uniform vec4 rim; // = vec4(1.0, 1.0, 1.0, 1.0)
// @color Color of the electrons
uniform vec4 electron; // = vec4(0.85, 0.95, 1.0, 1.0)

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;

float atomSmin(float a, float b, float r) {
  float h = max(r - abs(a - b), 0.0) / r;
  return min(a, b) - h * h * r * 0.25;
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float k = clamp(flatness, 0.1, 1.0);
  float g = pow(clamp((t - 0.15) / 0.85, 0.0, 1.0), 1.4);
  float fit = mix(0.4, 1.0, clamp(ratio, 0.0, 1.0));
  float far = 0.5 * length(vec2(ratio, 1.0));
  // the orbits grow to the frame's half diagonal
  float size = mix(0.28 * fit, far, g);
  float lane = 0.42 * size * k;
  float run = TAU * max(laps, 1.05) * (1.0 - (1.0 - t) * (1.0 - t));
  // just enough to close the pockets between the final orbits
  float grow = max(0.42 - 0.8 * k, 0.03) * far * g;
  float aa = 1.0 / 600.0;
  // rounds the crossings so the swelling ribbons merge instead of trapping specks
  float sk = 0.004 + 0.2 * far * g;
  float edge = 1.0;
  float spark = 0.0;
  float spin = 0.6 * t;
  for (int i = 0; i < 3; i++) {
    float a = spin + float(i) * PI / 3.0;
    vec2 q = mat2(cos(a), -sin(a), sin(a), cos(a)) * p;
    float f = length(vec2(q.x, q.y / k));
    // distance to the ellipse from its stretched radius, divided by the gradient's length
    float grad = length(vec2(q.x, q.y / (k * k))) / max(f, 1e-4);
    float d = abs(f - size) / max(grad, 1e-4);
    float start = float(i) * TAU / 3.0;
    float phi = mod(atan(q.y / k, abs(q.x) < 1e-6 ? 1e-6 : q.x) - start, TAU);
    // angle run since the electron first passed here, capped so the trail's tail tapers like its head and the two meet without a step
    float age = min(run - phi, max(run - TAU, 0.0) + phi);
    float w = lane * (0.12 + 0.5 * max(smoothstep(0.0, TAU, age), g)) + grow;
    edge = atomSmin(edge, mix(1.0, d - w, smoothstep(0.0, 0.2, age)), sk);
    float head = start + run;
    float r = length(q - vec2(cos(head), sin(head) * k) * size);
    spark += exp(-r / 0.014) + 0.6 * exp(-r / 0.045);
  }
  // starts below zero so the antialiased edge leaves the center untouched at progress 0
  float nr = (0.06 * fit + 2.0 * aa) * smoothstep(0.0, 0.25, t) - 2.0 * aa + grow + 0.8 * size * k * g;
  edge = atomSmin(edge, length(p) - nr, sk);
  float m = 1.0 - smoothstep(-aa, aa, edge);
  float on = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.75, 1.0, t));
  vec4 c = mix(getFromColor(uv), getToColor(uv), m);
  c = mix(c, vec4(rim.rgb, c.a), exp(-abs(edge) / 0.003) * min(2.0 * (1.0 - m), 1.0) * on * 0.7 * rim.a);
  return mix(c, vec4(electron.rgb, max(c.a, electron.a)), clamp(spark * on, 0.0, 1.0) * electron.a);
}
