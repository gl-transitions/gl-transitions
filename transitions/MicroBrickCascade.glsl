// Author: Gilad Levi
// License: MIT
// Description: The outgoing image fractures into a dense wall of tiny square tiles. A diagonal cascade releases the tiles in staggered waves, causing them to fall and drift aside while the incoming image is revealed beneath.
// Tags: mosaic, squares, falling, wall, brick, cascade, diagonal, pixel, cinematic

// @range(0.008, 0.060) Size of each square tile relative to frame height
uniform float tileSize; // = 0.018
// @range(0.0, 2.0) Downward falling strength of released tiles
uniform float fall; // = 1.10
// @range(0.0, 1.5) Sideways drift amount while tiles fall
uniform float drift; // = 0.35
// @range(0.0, 1.0) How diagonal the release wave is
uniform float diagonal; // = 0.82
// @range(0.0, 1.0) Random stagger amount between neighboring tiles
uniform float stagger; // = 0.45
// @range(0.0, 1.0) Softness of tile disappearance
uniform float softness; // = 0.22
// @range(0.0, 1.0) Brightness of the moving tile edge highlight
uniform float glow; // = 0.45

// ------------------------------------------------------------
// Stable pseudo-random generator based on tile coordinates
// Gives each tile unique timing and motion
// ------------------------------------------------------------
float hash12(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// ------------------------------------------------------------
// Main transition function
// uv        = pixel coordinate in normalized 0..1 space
// progress  = animation progress from 0..1
// ratio     = width / height
// getFromColor(uv) = current slide image
// getToColor(uv)   = next slide image
// ------------------------------------------------------------
vec4 transition(vec2 uv) {
  // Exact source/target at the boundaries
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  // ----------------------------------------------------------
  // 1) Build a dense square grid that stays visually square
  // even when the slider is wide
  // ----------------------------------------------------------
  float s = max(tileSize, 0.004);
  vec2 gridCount = max(vec2(1.0), floor(vec2(ratio, 1.0) / s));
  vec2 tile = floor(uv * gridCount);
  vec2 tileUV = fract(uv * gridCount);
  vec2 tileCenter = (tile + 0.5) / gridCount;

  // ----------------------------------------------------------
  // 2) Create a diagonal release wave
  // A higher diagonal value makes the cascade travel more
  // diagonally across the image
  // ----------------------------------------------------------
  float waveCoord = mix(
    tileCenter.x,
    0.65 * tileCenter.x + 0.35 * (1.0 - tileCenter.y),
    clamp(diagonal, 0.0, 1.0)
  );

  // ----------------------------------------------------------
  // 3) Add random tile staggering so the wall does not break
  // apart too uniformly
  // ----------------------------------------------------------
  float r1 = hash12(tile);
  float r2 = hash12(tile + vec2(19.1, 7.3));
  float r3 = hash12(tile + vec2(41.7, 13.9));

  float start = 0.08 + 0.60 * waveCoord + stagger * 0.12 * (r1 - 0.5);
  float t = clamp((progress - start) / 0.28, 0.0, 1.0);

  // ----------------------------------------------------------
  // 4) Compute tile motion
  // Tiles fall downward and drift slightly sideways
  // ----------------------------------------------------------
  float sideways = (r2 * 2.0 - 1.0) * drift * t;
  float downward = fall * t * t; // quadratic fall for gravity feel

  vec2 movedTileUV = tileUV - vec2(sideways, -downward);

  // ----------------------------------------------------------
  // 5) Determine whether the falling tile still covers the
  // current pixel inside its tile region
  // ----------------------------------------------------------
  float inside =
    step(0.0, movedTileUV.x) *
    step(movedTileUV.x, 1.0) *
    step(0.0, movedTileUV.y) *
    step(movedTileUV.y, 1.0);

  // ----------------------------------------------------------
  // 6) Fade tiles away smoothly as they move out
  // softness controls how abrupt or soft this disappearance is
  // ----------------------------------------------------------
  float fadeStart = mix(0.40, 0.15, softness);
  float fadeEnd   = mix(0.95, 0.65, softness);
  float visibility = inside * (1.0 - smoothstep(fadeStart, fadeEnd, t));

  // ----------------------------------------------------------
  // 7) Sample the outgoing image from the shifted tile position
  // This makes the tile appear to carry its image fragment with it
  // ----------------------------------------------------------
  vec2 shiftedUV = uv - vec2(sideways, -downward) / gridCount;
  vec4 fromColor = getFromColor(clamp(shiftedUV, 0.0, 1.0));

  // Incoming image stays stable behind the wall
  vec4 toColor = getToColor(uv);

  // Blend the falling old tile over the new image
  vec4 color = mix(toColor, fromColor, visibility);

  // ----------------------------------------------------------
  // 8) Add a subtle highlight to moving tile edges
  // This helps the tiny squares read more clearly
  // ----------------------------------------------------------
  float edgeDistance = min(
    min(movedTileUV.x, 1.0 - movedTileUV.x),
    min(movedTileUV.y, 1.0 - movedTileUV.y)
  );

  float edge = (1.0 - smoothstep(0.0, 0.08, edgeDistance)) * inside;
  float sparkle = sin(t * 3.14159265) * glow * visibility;

  vec3 edgeColor = mix(
    vec3(0.12, 0.90, 1.0),
    vec3(1.0, 0.35, 0.65),
    r3
  );

  color.rgb += edgeColor * edge * sparkle * 0.45;
  color.rgb = clamp(color.rgb, 0.0, 1.0);

  return color;
}
