// Author: gre
// License: MIT
// Description: Soft, glossy blobs of liquid pop up over the outgoing image, swell and melt into each other, revealing the incoming image until they cover the whole frame
// Tags: blob, liquid, organic, reveal

// @range(2, 12, 1) Number of blobs across the frame
uniform float blobs; // = 5.0
// @range(0, 1) How smoothly neighbouring blobs melt into each other
uniform float smoothness; // = 0.5
// @color Color of the glossy highlight on the rim of the blobs (its alpha is its strength)
uniform vec4 highlight; // = vec4(1.0, 1.0, 1.0, 0.7)
// @color Color of the soft shadow that the blobs cast on the outgoing image
uniform vec4 shadow; // = vec4(0.0, 0.0, 0.0, 0.3)

float hash (vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 fold (vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

// signed distance to the blob of a grid cell (in cells), its center returned in .yz
vec3 blob (vec2 cell, float rStart, float rEnd) {
  vec2 c = cell + 0.5 + 0.7 * (vec2(hash(cell + 0.5), hash(cell + 41.3)) - 0.5);
  float t0 = 0.02 + 0.43 * hash(cell + 17.9); // when it pops up
  float s = clamp((progress - t0) / (1.0 - t0), 0.0, 1.0);
  // it pops up fast with a little wobble, then swells slowly
  float pop = clamp((progress - t0) / 0.12, 0.0, 1.0);
  pop = 1.0 - (1.0 - pop) * (1.0 - pop) * (1.0 - pop);
  float r = mix(rStart, 0.18, pop) + (rEnd - 0.18) * s * sqrt(s);
  r += 0.05 * sin(pop * 9.0) * (1.0 - s) * pop;
  return vec3(r, c);
}

vec4 transition (vec2 uv) {
  float n = max(1.0, floor(blobs + 0.5));
  float cellSize = max(ratio, 1.0) / n;
  vec2 q = vec2(uv.x * ratio, uv.y) / cellSize; // in cells
  vec2 base = floor(q);
  float k = 0.02 + 0.25 * smoothness; // melting distance, in cells
  float w = 0.16; // width of the rounded rim, in cells
  // a blob starts far enough below the surface not to show (the union of 49 blobs bulges by up to k * log(49)),
  // and ends up covering the whole of its cell (its center is at most 0.85 * sqrt(2) cells away) and its rim
  float rStart = -(0.03 + 4.0 * k);
  float rEnd = 0.85 * sqrt(2.0) + w + 0.05;
  // smooth union (log-sum-exp, computed online) of the blobs around, with its gradient;
  // blobs further than 3 cells away weigh less than exp(-7) and are left out
  float m = 1e3; // distance to the nearest blob
  float sum = 0.0;
  vec2 grad = vec2(0.0);
  float rNear = 0.0; // radius of the nearest blob
  for (int j = -3; j <= 3; j++) {
    for (int i = -3; i <= 3; i++) {
      vec3 b = blob(base + vec2(float(i), float(j)), rStart, rEnd);
      vec2 dq = q - b.yz;
      float l = length(dq);
      float dist = l - b.x;
      vec2 g = dq / max(l, 1e-4);
      if (dist < m) {
        float scale = exp((dist - m) / k);
        sum = sum * scale + 1.0;
        grad = grad * scale + g;
        m = dist;
        rNear = b.x;
      } else {
        float wt = exp((m - dist) / k);
        sum += wt;
        grad += wt * g;
      }
    }
  }
  float d = m - k * log(sum); // < 0 inside the goo
  grad /= sum;
  float aa = 0.012 * n / 5.0;
  float inside = 1.0 - smoothstep(-aa, aa, d);
  // a rounded, glossy surface near the edge, flat further inside; the goo settles flat at the end
  float h = clamp(-d / w, 0.0, 1.0);
  float settle = 1.0 - smoothstep(0.45, 0.85, progress);
  float tilt = (1.0 - h) * (1.0 - h) * settle;
  vec3 nrm = normalize(vec3(grad * tilt * 3.0, 1.0));
  vec3 halfway = normalize(vec3(-0.35, 0.45, 1.0) + vec3(0.0, 0.0, 1.0));
  float spec = pow(max(dot(nrm, halfway), 0.0), 200.0) * settle;
  // thick, opaque goo: darker toward its edge, more so on the side away from the light
  float shade = 1.0 - tilt * (0.25 + 0.3 * clamp(dot(grad, vec2(0.6, -0.8)) + 0.3, 0.0, 1.0));
  vec4 to = getToColor(fold(uv - grad * tilt * 0.01 * cellSize / vec2(ratio, 1.0)));
  float t2 = tilt * tilt;
  float gloss = 0.3 * t2 * t2; // a thin bright line right on the rim
  to.rgb = mix(to.rgb * shade, highlight.rgb * to.a, clamp(spec + gloss, 0.0, 1.0) * highlight.a);
  vec4 from = getFromColor(uv);
  float sh = shadow.a * (1.0 - smoothstep(0.0, 0.15, d + 0.03)) * smoothstep(0.0, 0.3, rNear);
  from.rgb = mix(from.rgb, shadow.rgb * from.a, sh);
  return mix(from, to, inside);
}
