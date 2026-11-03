// Author: gre
// License: MIT
// Description: Tape-tracking bands of white snow roll down the frame, tearing the lines around them, with smeared color, wobbling lines, a jittering strip at the bottom and a dropout flash, as the incoming image is recorded over the outgoing one under the densest band
// Tags: retro, glitch, noise, tape, scanlines

// @range(1, 4, 1) Number of noise bands rolling down (the first one carries the cut)
uniform int bands; // = 3
// @range(0, 1) Amount of snow and tearing in the bands
uniform float noise; // = 0.6
// @range(0, 1) How far the color smears to the right of the picture
uniform float bleed; // = 0.5
// @range(0, 1) How much the lines wobble sideways
uniform float wobble; // = 0.5

const float LINES = 220.0; // tape lines over the frame height
const float FRAMES = 40.0; // the noise changes this many times over the transition
const float BAND = 0.11; // half height of the main band
const float STRIP = 0.06; // height of the jittering strip at the bottom
const int TAPS = 6;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the tape image on the outgoing (or, once re-recorded, incoming) side, premultiplied
vec4 tape(vec2 p, bool fresh) {
  p = mirror(p);
  vec4 c = fresh ? getToColor(p) : getFromColor(p);
  return vec4(c.rgb * c.a, c.a);
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// how dense a band centered at y = c of half height w is on line y, with ragged edges
float bandDensity(float y, float c, float w, float jitter) {
  float d = abs(y - c) / w + 0.35 * jitter;
  return 1.0 - smoothstep(0.0, 1.0, d);
}

vec4 transition(vec2 uv) {
  // the effects build up quickly and settle at the end: exactly 0 at both ends
  float h = clamp(2.5 * (1.0 - abs(2.0 * progress - 1.0)), 0.0, 1.0);
  float env = h * h * (3.0 - 2.0 * h);
  // a short dropout flash when the main band crosses the middle of the frame
  float f = clamp(1.0 - abs(progress - 0.5) / 0.04, 0.0, 1.0);
  float flash = f * f * (3.0 - 2.0 * f);

  float frame = floor(progress * FRAMES);
  float line = floor(uv.y * LINES);
  float jitter = hash12(vec2(line, frame + 7.0)) - 0.5;

  // the main band rolls from above the frame to below it; the incoming image is above it
  float c0 = mix(1.0 + 1.2 * BAND, -1.2 * BAND, progress);
  // (the cut is ragged, line by line)
  bool fresh = uv.y > c0 + 0.8 * BAND * jitter;
  float dens = bandDensity(uv.y, c0, BAND, jitter);
  float tear = 1.0 - smoothstep(0.0, 1.0, abs(uv.y - c0) / (2.5 * BAND));
  // thinner and weaker bands roll faster, wrapping around the frame
  for (int i = 1; i < 4; i++) {
    if (i < bands) {
      float k = float(i);
      float w = BAND * (0.35 + 0.2 * hash12(vec2(k, 3.0)));
      float speed = 1.3 + 0.9 * k;
      float cy = -w + (1.0 + 2.0 * w) * fract(hash12(vec2(k, 5.0)) - speed * progress);
      dens = max(dens, 0.6 * bandDensity(uv.y, cy, w, jitter));
      tear = max(tear, 0.5 * (1.0 - smoothstep(0.0, 1.0, abs(uv.y - cy) / (2.5 * w))));
    }
  }
  dens *= env;
  tear *= env;

  // horizontal displacement of the line: a slow wobble, a fine jitter and the tearing
  float rowTear = hash12(vec2(floor(uv.y * LINES * 0.5), frame + 31.0)) - 0.5;
  float dx = wobble * env * (0.006 * sin(uv.y * 7.0 + progress * 23.0) + 0.004 * jitter);
  dx += (0.3 + 0.7 * noise) * tear * 0.18 * rowTear;
  // the head-switching strip at the bottom: lines skewed sideways and jittering
  float strip = env * (1.0 - smoothstep(0.0, STRIP, uv.y));
  dx += strip * (0.03 + 0.06 * (1.0 - uv.y / STRIP)) * (0.6 + 0.8 * hash12(vec2(frame, 41.0)));
  vec2 q = vec2(uv.x + dx, uv.y);

  vec4 c = tape(q, fresh);
  if (c.a <= 0.0) return vec4(0.0);
  // chroma bleed: the color is smeared to the right of the luma
  float len = bleed * (0.02 + 0.05 * dens) * env;
  vec4 avg = c;
  if (len > 0.0) {
    avg = vec4(0.0);
    for (int i = 0; i < TAPS; i++) {
      float u = (float(i) + 0.5) / float(TAPS);
      avg += tape(q - vec2(len * (0.4 + u), 0.0), fresh);
    }
    avg /= float(TAPS);
  }
  vec3 chroma = (avg.rgb - luma(avg.rgb)) / max(avg.a, 1e-5);
  vec3 rgb = luma(c.rgb) + chroma * c.a; // premultiplied by c.a
  // the signal fades and loses color under the bands
  rgb = mix(rgb, vec3(luma(rgb)), 0.6 * dens);

  // snow: short white streaks on the tape lines, denser in the bands
  // (the streaks of each line start at a random offset so they never line up vertically)
  vec2 cell = vec2(floor(uv.x * LINES * 0.3 * ratio + 40.0 * jitter), line);
  float n = hash12(cell + frame * vec2(37.0, 17.0));
  float amount = clamp(noise * max(1.3 * dens, 0.8 * strip) + 0.35 * flash, 0.0, 1.0);
  float snow = amount > 0.0 ? smoothstep(1.0 - amount, 1.0 - 0.6 * amount, n) : 0.0;
  snow *= 0.55 + 0.45 * hash12(cell.yx + frame);
  // and a finer sparkle between them
  float g = hash12(vec2(floor(uv.x * LINES * ratio), line) + frame * vec2(13.0, 29.0));
  snow = max(snow, amount > 0.0 ? 0.7 * smoothstep(1.0 - 0.4 * amount, 1.0, g) : 0.0);
  // and a few dark specks
  float dark = g < 0.1 * amount ? 1.0 : 0.0;
  // the dropout: whole stretches of a few lines go white
  float group = floor(uv.y * LINES / 3.0);
  float drop = step(1.0 - 0.15 * flash, hash12(vec2(group, floor(uv.x * 6.0 + 5.0 * hash12(vec2(group, frame))) + frame * 7.0)));
  rgb *= 1.0 - 0.5 * dark;
  rgb += (clamp(snow + drop + 0.12 * flash, 0.0, 1.0)) * (c.a - rgb);

  return vec4(clamp(rgb / c.a, 0.0, 1.0), c.a);
}
