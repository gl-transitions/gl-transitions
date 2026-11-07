// Author: lbl
// License: MIT
// Description: The outgoing image cracks like a pane of glass from an impact point, then its shards break loose from the impact outward, tumbling in 3D and falling away with gravity to reveal the incoming image behind
// Tags: shatter, fragments, glass, 3d

// @param Impact point where the cracks start, from (0, 0) at the bottom left to (1, 1) at the top right
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(3, 12) Approximate number of shards across the height of the frame
uniform float shards; // = 7.0
// @range(0.5, 3) Strength of the gravity: the shards fall faster, and break loose over a longer time
uniform float gravity; // = 1.0
// @param Random seed: another value gives other shards, tumbling another way
uniform float seed; // = 0.0

// distance from the camera to the pane, as a part of the frame's height
const float EYE = 2.0;
// width of the anti-aliased edges, the crack lines and the bevels, as a part of the frame's height
const float EDGE = 0.0012;
const float CRACK_WIDTH = 0.0025;
const float BEVEL = 0.006;

vec3 hash32(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float cellSize() {
  return 1.0 / clamp(shards, 3.0, 12.0);
}

vec2 seedOffset() {
  return vec2(37.0, 17.0) * floor(seed);
}

// the seed point of the shard of cell c
vec2 shardSeed(vec2 c) {
  return (c + 0.15 + 0.7 * hash32(c + seedOffset()).xy) * cellSize();
}

// the shard that contains q on the unbroken pane: (its cell, the distance from q to its nearest crack,
// the neighbor across that crack as (dx + 1) + 3 * (dy + 1))
vec4 shardAt(vec2 q) {
  float s = cellSize();
  vec2 g = floor(q / s);
  vec2 nc = g;
  vec2 np = shardSeed(g);
  float best = 1e9;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 c = g + vec2(float(x), float(y));
      vec2 sp = shardSeed(c);
      float d = dot(q - sp, q - sp);
      if (d < best) {
        best = d;
        nc = c;
        np = sp;
      }
    }
  }
  float ed = 1e9;
  float nb = 4.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      if (x == 0 && y == 0) continue;
      vec2 sp = shardSeed(nc + vec2(float(x), float(y)));
      float d = dot(0.5 * (np + sp) - q, normalize(sp - np));
      if (d < ed) {
        ed = d;
        nb = float(x + 1 + 3 * (y + 1));
      }
    }
  }
  return vec4(nc, ed, nb);
}

vec2 impact() {
  return clamp(center, 0.0, 1.0) * vec2(ratio, 1.0);
}

// distance from the impact to the farthest corner of the frame
float reach() {
  vec2 c = impact();
  return length(max(c, vec2(ratio, 1.0) - c));
}

float gravityAcc() {
  return 12.0 * clamp(gravity, 0.5, 3.0);
}

// the time a shard whose seed is at the height y takes to fall out of the frame
float fallTime(float y) {
  return sqrt(2.0 * (y + 0.1 + 1.5 * cellSize()) / gravityAcc());
}

// the time the cracks take to run from the impact to the farthest corner, before the last shards break loose
float crackTime() {
  return clamp(0.6 * (0.94 - fallTime(1.0)), 0.05, 0.22);
}

// the time a shard breaks loose: the nearer the impact the sooner, and late enough to fall out of the frame by the end
float releaseTime(vec2 c, vec2 sp) {
  float dn = clamp(length(sp - impact()) / reach(), 0.0, 1.0);
  float latest = max(0.98 - fallTime(sp.y), 0.04);
  return 0.04 + (latest - 0.04) * (0.8 * pow(dn, 0.8) + 0.2 * hash32(c + seedOffset() + 0.5).z);
}

// a flash at the impact, at the start
float flash(vec2 q) {
  float f = sin(3.141592653589793 * clamp(progress / 0.12, 0.0, 1.0));
  vec2 d = q - impact();
  return 0.6 * f * exp(-dot(d, d) / (0.004 + 0.02 * progress));
}

// Rodrigues' rotation of v around the unit axis k
vec3 rotate(vec3 v, vec3 k, float a) {
  float c = cos(a), s = sin(a);
  return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float s = cellSize();
  vec2 a = vec2(uv.x * ratio, uv.y);
  vec3 eye = vec3(0.5 * ratio, 0.5, -EYE);
  vec3 ray = vec3(a, 0.0) - eye;
  vec3 light = normalize(vec3(-0.35, 0.55, -1.0));
  vec3 view = -normalize(ray);
  vec3 halfway = normalize(light + view);
  float g = gravityAcc();
  vec2 imp = impact();

  // the part of the pane still in place, behind the loose shards
  vec4 pane = vec4(0.0);
  float paneCover = 0.0;
  vec4 here = shardAt(a);
  if (progress < releaseTime(here.xy, shardSeed(here.xy))) {
    vec4 col = getFromColor(uv);
    // the cracks run along the shards' edges from the impact
    float crack = clamp((progress - crackTime() * length(a - imp) / reach()) / 0.03, 0.0, 1.0);
    // cracked shards settle at slightly different angles (no change while flat: dot(n, light) = -light.z)
    vec3 h = hash32(here.xy + seedOffset() + 0.25);
    vec3 n = rotate(vec3(0.0, 0.0, -1.0), normalize(vec3(h.xy - 0.5, 0.0) + 1e-4), 0.06 * crack * (h.z - 0.5));
    col.rgb *= 1.0 + 1.2 * (dot(n, light) + light.z);
    col.rgb += crack * 0.35 * pow(max(dot(n, halfway), 0.0), 400.0) * col.a;
    float line = crack * (1.0 - smoothstep(0.0, CRACK_WIDTH, here.z));
    col.rgb = mix(col.rgb, vec3(0.95, 0.98, 1.0) * col.a, 0.85 * line);
    col.rgb += flash(a) * col.a;
    pane = col;
    // anti-aliased along the crack once the shard across it has broken loose
    vec2 nc = here.xy + vec2(mod(here.w, 3.0), floor(here.w / 3.0)) - 1.0;
    float gone = smoothstep(0.0, 0.04, progress - releaseTime(nc, shardSeed(nc)));
    paneCover = mix(1.0, smoothstep(0.0, 2.0 * EDGE, here.z), gone);
  }
  float paneDepth = paneCover > 0.0 ? 1.0 : 1e9;

  // the two nearest loose shards: depth along the ray, color, coverage
  float t1 = 1e9, t2 = 1e9;
  vec4 c1 = vec4(0.0), c2 = vec4(0.0);
  float a1 = 0.0, a2 = 0.0;
  float shadow = 0.0;

  // the shards that broke loose, searched among the cells around and above the pixel since they fall
  vec2 g0 = floor(a / s) - vec2(4.0, 3.0);
  float rows = ceil(1.0 / s) + 1.0;
  for (int ri = 0; ri < 18; ri++) {
    float j = g0.y + float(ri);
    if (j > rows) break;
    if (j < -1.0) continue;
    for (int ci = 0; ci < 9; ci++) {
      vec2 c = vec2(g0.x + float(ci), j);
      vec2 sp = shardSeed(c);
      float e = progress - releaseTime(c, sp);
      if (e <= 0.0) continue;
      vec3 h1 = hash32(c + seedOffset() + 0.25);
      vec3 h2 = hash32(c + seedOffset() + 0.75);
      // pushed away from the impact and toward the camera, spinning around a random axis, falling
      vec2 away = sp - imp;
      float near = 1.0 - clamp(length(away) / reach(), 0.0, 1.0);
      away = away / max(length(away), 1e-3);
      vec3 vel = vec3(away * (0.05 + 0.2 * h1.x) * (0.4 + near), -(0.12 + 0.35 * near * h1.y));
      vec3 pos = vec3(sp, 0.0) + vel * e + vec3(0.0, -0.5 * g * e * e, 0.0);
      // already out of the frame, or too far below to reach this pixel
      if (pos.y + 1.7 * s < -0.05 || pos.y - 1.7 * s > a.y + 0.4) continue;
      vec3 axis = normalize(vec3(h1.z - 0.5, h2.x - 0.5, 0.3 * (h2.y - 0.5)) + 1e-4);
      float angle = (3.0 + 5.0 * h2.z) * (h2.x < 0.5 ? -1.0 : 1.0) * e;
      vec3 n = rotate(vec3(0.0, 0.0, -1.0), axis, angle);
      float rel = smoothstep(0.0, 0.04, e);

      // the camera ray, hidden behind the pane still in place
      float den = dot(ray, n);
      if (abs(den) > 1e-4) {
        float t = dot(pos - eye, n) / den;
        vec2 l = rotate(eye + t * ray - pos, axis, -angle).xy;
        vec2 q = sp + l;
        if (t > 0.0 && t < t2 && t < paneDepth && dot(l, l) < 2.6 * s * s && q.x > 0.0 && q.y > 0.0 && q.x < ratio && q.y < 1.0) {
          vec4 at = shardAt(q);
          if (at.x == c.x && at.y == c.y) {
            float border = min(min(q.x, ratio - q.x), min(q.y, 1.0 - q.y));
            float ed = min(at.z, border);
            float cover = mix(1.0, smoothstep(0.0, 2.0 * EDGE, ed), rel);
            vec3 nf = den > 0.0 ? -n : n;
            vec4 col = getFromColor(vec2(q.x / ratio, q.y));
            float shade = clamp(dot(nf, light) / -light.z, 0.45, 1.1);
            col.rgb *= mix(1.0, shade, rel);
            float glint = max(dot(nf, halfway), 0.0);
            col.rgb += (rel * 0.3 * pow(glint, 60.0) + flash(q)) * col.a;
            // the crack line it carried turns into a bright bevel
            float line = 0.85 * (1.0 - smoothstep(0.0, CRACK_WIDTH, at.z));
            float bevel = 0.8 * rel * (1.0 - smoothstep(0.0, BEVEL, ed)) * (0.3 + 0.7 * pow(glint, 6.0));
            col.rgb = mix(col.rgb, vec3(0.92, 0.97, 0.97) * col.a, max(line * (1.0 - rel), bevel));
            if (t < t1) {
              t2 = t1; c2 = c1; a2 = a1;
              t1 = t; c1 = col; a1 = cover;
            } else {
              t2 = t; c2 = col; a2 = cover;
            }
          }
        }
      }

      // the shadow on the pane and on the incoming image behind
      float lden = dot(light, n);
      if (abs(lden) > 1e-4) {
        float t = dot(pos - vec3(a, 0.0), n) / lden;
        vec2 l = rotate(vec3(a, 0.0) + t * light - pos, axis, -angle).xy;
        vec2 q = sp + l;
        if (t > 0.0 && dot(l, l) < 2.6 * s * s && q.x > 0.0 && q.y > 0.0 && q.x < ratio && q.y < 1.0) {
          vec4 at = shardAt(q);
          if (at.x == c.x && at.y == c.y) {
            float border = min(min(q.x, ratio - q.x), min(q.y, 1.0 - q.y));
            float soft = smoothstep(0.0, 0.004 + 0.08 * t, min(at.z, border));
            shadow = max(shadow, rel * soft * 0.45 * (1.0 - smoothstep(0.1, 0.9, t)));
          }
        }
      }
    }
  }

  // the incoming image behind, then the pane still in place, then the loose shards in front
  vec4 back = getToColor(uv);
  back.rgb *= 1.0 - shadow;
  pane.rgb *= 1.0 - shadow;
  back = mix(back, pane, paneCover);
  return c1 * a1 + c2 * min(a2, 1.0 - a1) + back * max(1.0 - a1 - a2, 0.0);
}
