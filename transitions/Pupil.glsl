// Author: gre
// License: MIT
// Description: The outgoing picture turns out to be what an eye is looking at: the view backs out of the pupil, which shrinks to a pinpoint in a huge iris whose fibers take their colors from the picture; the eye stares, its colors turn, and the pupil dilates wide open on the incoming picture
// Tags: eye, zoom, surreal, organic, macro

// @range(0.4, 0.8) Radius of the iris, relative to the shorter side of the frame
uniform float size; // = 0.6
// @range(0.04, 0.2) Radius of the pupil at its tightest, relative to the shorter side of the frame
uniform float pinpoint; // = 0.1
// @range(0, 1) Depth of the iris fibers
uniform float fibers; // = 0.8
// @color White of the eye
uniform vec4 sclera; // = vec4(0.93, 0.92, 0.91, 1.0)

const float PI = 3.14159265;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// periodic in x with period n
float noise(vec2 p, float n) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  // not mod(), which may return n itself on some GPUs; callers stay under 2n
  float x0 = i.x - n * step(n, i.x);
  float x1 = i.x + 1.0 - n * step(n, i.x + 1.0);
  return mix(mix(hash(vec2(x0, i.y)), hash(vec2(x1, i.y)), f.x),
             mix(hash(vec2(x0, i.y + 1.0)), hash(vec2(x1, i.y + 1.0)), f.x), f.y);
}

// atan is too coarse on some targets for the fine fibers
float turn(vec2 v) {
  vec2 w = abs(v);
  float z = min(w.x, w.y) / max(max(w.x, w.y), 1e-6);
  float z2 = z * z;
  float a = z * (0.99997726 + z2 * (-0.33262347 + z2 * (0.19354346 + z2 * (-0.11643287 + z2 * (0.05265332 - 0.0117212 * z2)))));
  a = w.y > w.x ? 0.5 * PI - a : a;
  a = v.x < 0.0 ? PI - a : a;
  a = v.y < 0.0 ? 2.0 * PI - a : a;
  return a / (2.0 * PI);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 pictures(vec2 uv, float k) {
  vec4 a = getFromColor(mirror(uv));
  vec4 b = getToColor(mirror(uv));
  return mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), k);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float side = min(ratio, 1.0);
  float Rmax = 0.5 * length(asp) * 1.08;
  float sz = max(size, 0.1) * side;
  float pin = clamp(pinpoint, 0.01, 0.4) * side;

  float shut = smoothstep(0.0, 0.46, p) * (1.0 - smoothstep(0.5, 1.0, p));
  float mid = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.7, 1.0, p));
  float swap = smoothstep(0.4, 0.56, p);
  // interpolating the log radius keeps the zoom rate even
  float R = exp(mix(log(Rmax), log(pin), shut));
  // the pupil quivers as it adjusts
  float tw = (p - 0.48) / 0.12;
  R *= 1.0 + 0.09 * mid * sin(p * 40.0) * exp(-tw * tw);

  vec2 gaze = side * vec2(0.07, 0.03) * sin(p * PI * vec2(2.0, 4.0)) * mid;
  vec2 d = q - gaze * (1.0 - smoothstep(0.3, 0.9, R / side));
  float r = length(d);
  vec2 dir = d / max(r, 1e-5);
  float th = turn(d);

  // ruffled edge of the pupil, pulled by the fibers
  float ruff = noise(vec2(th * 54.0, 2.0), 54.0) + 0.5 * noise(vec2(th * 130.0, 5.0), 130.0) - 0.75;
  float Rp = R * (1.0 + 0.07 * mid * ruff);
  float Ri = sqrt(sz * sz + 1.9 * R * R);
  float s = clamp((r - Rp) / (Ri - Rp), 0.0, 1.0);
  float dilated = smoothstep(0.1, 0.5, R / side);

  vec4 tone4 = vec4(0.0);
  for (int i = 0; i < 4; i++) {
    float k = (float(i) + 0.5) / 4.0;
    tone4 += 0.25 * pictures(0.5 + dir * side / asp * (0.12 + 0.34 * k + 0.1 * s), swap);
  }
  vec3 tone = tone4.a > 0.0 ? tone4.rgb / tone4.a : vec3(0.0);

  float wob = 1.1 * noise(vec2(th * 20.0, s * 3.0), 20.0);
  float f1 = noise(vec2(th * 120.0 + wob * 1.6, s * 2.4), 120.0);
  float f2 = noise(vec2(th * 300.0 + wob * 2.5, s * 4.0 + 9.0), 300.0);
  float f3 = noise(vec2(th * 44.0 + wob, s * 1.5 + 4.0), 44.0);
  // the finest fibers are thinner than a pixel around a tight pupil
  f1 = mix(0.5, f1, smoothstep(0.02, 0.08, r));
  f2 = mix(0.5, f2, smoothstep(0.04, 0.16, r));
  float strand = 1.0 - abs(2.0 * f1 - 1.0);
  float fib = 0.45 * strand * strand + 0.3 * f2 + 0.45 * f3;

  // zigzag collarette, crypts opening just outside it, contraction furrows when the pupil dilates
  float coll = 0.28 + 0.11 * (noise(vec2(th * 30.0, 1.0), 30.0) - 0.5) + 0.04 * (f3 - 0.5);
  float cx = (s - coll) / 0.035;
  float ridge = exp(-cx * cx);
  float pit = noise(vec2(th * 42.0 + 0.5 * wob, s * 6.0 + 17.0), 42.0);
  float zone = smoothstep(coll, coll + 0.08, s) * (1.0 - smoothstep(0.55, 0.85, s));
  float crypt = smoothstep(0.6, 0.76, pit) * zone;
  float brink = smoothstep(0.48, 0.6, pit) * (1.0 - smoothstep(0.6, 0.7, pit)) * zone;
  float wave = 7.3 * (s + 0.03 * noise(vec2(th * 12.0, 8.0), 12.0));
  float furrow = sin(2.0 * PI * wave) * smoothstep(0.45, 0.62, s) * noise(vec2(th * 9.0, floor(wave) + 3.0), 9.0);

  float lum = dot(tone, vec3(0.299, 0.587, 0.114));
  vec3 iris = max(mix(vec3(lum), tone, 1.6), 0.0) / (0.75 + 0.45 * lum) + 0.05;
  iris *= 1.3;
  iris /= 1.0 + 0.6 * max(max(iris.r, iris.g), iris.b);
  float deep = fibers * (0.3 + 0.7 * mid);
  iris *= mix(1.0, 0.3 + 1.25 * fib, deep);
  iris *= 1.0 - 0.42 * deep * crypt;
  iris *= 1.0 + 0.35 * deep * brink;
  iris *= 1.0 - 0.22 * deep * furrow * (0.35 + 0.65 * dilated);
  iris = mix(iris, iris * vec3(1.3, 1.05, 0.75), 1.0 - smoothstep(coll - 0.05, coll + 0.1, s));
  iris += ridge * 0.22 * fib * (tone + 0.2);
  iris *= mix(0.22, 1.0, smoothstep(0.0, 0.13, s + 0.04 * (f1 - 0.5)));
  iris *= 1.0 - 0.8 * smoothstep(0.76, 1.0, s + 0.1 * (fib - 0.55));
  vec2 toLight = vec2(-0.5547, 0.8321);
  // light from the upper left gathers on the far side of the iris
  iris *= 1.0 - 0.4 * dot(dir, toLight) * smoothstep(0.1, 0.6, s);

  float out1 = (r - Ri) / side;
  vec3 white = sclera.rgb * mix(vec3(1.0), tone + 0.35, 0.25 * tone4.a) * (1.0 - vec3(0.0, 0.1, 0.1) * smoothstep(0.1, 0.6, out1));
  white *= 1.0 - 0.4 * smoothstep(0.1, 0.6, out1) - 0.4 * exp(-max(out1, 0.0) * 18.0);
  vec4 eye = mix(vec4(iris * tone4.a, tone4.a), vec4(white * sclera.a, sclera.a), smoothstep(-0.02, 0.05, out1));

  // a picture as seen in the dark of the pupil: rounded by the cornea, the disc takes in the shorter side
  float f = 0.5 * side;
  float scale = pow(1.0 + pow(f / R, 8.0), 0.125) / pow(1.0 + pow(f / Rmax, 8.0), 0.125);
  float rr = min(r / R, 1.0);
  float bulge = 1.0 - 0.3 * (1.0 - rr * rr) * smoothstep(0.0, 0.5, shut);
  vec4 seen = pictures(0.5 + d / asp * scale * bulge, swap);
  seen.rgb *= 1.0 - 0.75 * smoothstep(0.0, 0.4, shut) * smoothstep(0.45, 1.0, rr);

  float soft = min(0.006, 0.1 * R);
  vec4 c = mix(seen, eye, smoothstep(-soft, soft, r - Rp));

  // a curved softbox on the cornea, lit by the other picture, sliding against the gaze
  vec2 w = d + 0.6 * gaze;
  float wr = length(w);
  vec2 wd = w / max(wr, 1e-5);
  float across = wd.x * toLight.y - wd.y * toLight.x;
  vec2 box = vec2(across / 0.36, (wr / sz - 0.56) / 0.16);
  vec2 ab = abs(box);
  float corner = pow(ab.x * ab.x * ab.x * ab.x + ab.y * ab.y * ab.y * ab.y, 0.25);
  float win = (1.0 - smoothstep(0.55, 1.0, corner)) * step(0.0, dot(wd, toLight));
  float shown = mid * (1.0 - smoothstep(0.35, 0.9, R / sz));
  vec4 shine = pictures(0.5 + vec2(0.06, 0.42) * box, 1.0 - swap);
  float low = length((w + toLight * 0.68 * sz) / sz);
  vec3 light = win * (0.3 * shine.a + 0.55 * shine.rgb) * (0.75 + 0.25 * box.y);
  light += 0.14 * exp(-low * low * 26.0) * (tone4.rgb + 0.3 * tone4.a);
  c.rgb += shown * light * (c.a - 0.6 * c.rgb);
  // shadow of the upper lid
  vec2 lid = q / side;
  c.rgb *= 1.0 - 0.45 * mid * (1.0 - smoothstep(0.2, 0.6, R / side)) * smoothstep(0.12, 0.62, lid.y - 0.25 * lid.x * lid.x);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
