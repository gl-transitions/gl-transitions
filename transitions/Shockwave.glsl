
 // Author: Gilad Levi, github @Giladx
 // License: MIT
 // Description: A diagonal shockwave breaks the outgoing image into tiny falling glass tiles. Each tile slips away with a brief chromatic split and neon edge glow, revealing the incoming image beneath it.
 // Tags: diagonal, mosaic, pixel, cascade, glass, prism, chromatic, neon, cinematic

 // @range(0.012, 0.10) Size of each square tile relative to slide height
 uniform float tileSize; // = 0.035
 // @range(0.0, 1.5) How far the tiles slide and fall
 uniform float scatter; // = 0.85
 // @range(0.0, 1.0) 0 is a horizontal sweep; 1 is a strongly diagonal sweep
 uniform float diagonal; // = 0.9
 // @range(0.0, 1.0) Amount of red/blue optical separation at the moving edges
 uniform float prism; // = 0.65
 // @range(0.0, 1.0) Brightness of the colored edges around moving tiles
 uniform float glow; // = 0.75

 // A deterministic pseudo-random value per cell, stable between frames.
 float toseeHash(vec2 p) {
   return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
 }

 vec4 transition(vec2 uv) {
   // Preserve perfect, undistorted source and destination frames.
   if (progress <= 0.0) return getFromColor(uv);
   if (progress >= 1.0) return getToColor(uv);

   // Build an aspect-correct grid: square cells on wide and tall sliders.
   float size = max(tileSize, 0.008);
   vec2 grid = max(vec2(1.0), floor(vec2(ratio, 1.0) / size));
   vec2 cell = floor(uv * grid);
   vec2 cellUV = fract(uv * grid);
   vec2 centerUV = (cell + 0.5) / grid;

   // Schedule each tile in a diagonal wave with random stagger.
   float sweep = mix(
     centerUV.x,
     0.64 * centerUV.x + 0.36 * (1.0 - centerUV.y),
     clamp(diagonal, 0.0, 1.0)
   );

   float noise = toseeHash(cell);
   float start = 0.62 * sweep + 0.07 * noise;
   float t = clamp((progress - start) / 0.29, 0.0, 1.0);
   float movement = t * clamp(scatter, 0.0, 1.5);

   // Move each outgoing image tile sideways and downward.
   float wobble = toseeHash(cell + vec2(19.3, 7.7)) * 2.0 - 1.0;
   vec2 drift = vec2(0.65 * wobble, -0.95) * movement;
   vec2 movingCellUV = cellUV - drift;

   // Clip moving tiles to their cells, revealing the next image.
   float inside =
     step(0.012, movingCellUV.x) *
     step(movingCellUV.x, 0.988) *
     step(0.012, movingCellUV.y) *
     step(movingCellUV.y, 0.988);

   float tileShape = mix(1.0, inside, smoothstep(0.0, 0.13, t));
   float oldVisibility = 1.0 - smoothstep(0.48, 0.87, t);
   float oldMask = tileShape * oldVisibility;

   // Sample the old image using the tile's displaced position.
   vec2 oldUV = clamp(uv - drift / grid, 0.0, 1.0);
   vec4 oldColor = getFromColor(oldUV);

   // Add chromatic separation while each tile is moving.
   float flare = sin(3.14159265 * t);
   vec2 shift = vec2(0.006, -0.002) * prism * flare;
   vec4 offsetColor = getFromColor(
     clamp(oldUV + shift, 0.0, 1.0)
   );
   oldColor.r = offsetColor.r;

   // Reveal the incoming image below the falling tiles.
   vec4 result = mix(getToColor(uv), oldColor, oldMask);

   // Draw a temporary cyan or pink glowing rim around moving tiles.
   float edgeDistance = min(
     min(movingCellUV.x, 1.0 - movingCellUV.x),
     min(movingCellUV.y, 1.0 - movingCellUV.y)
   );

   float edge =
     (1.0 - smoothstep(0.0, 0.10, edgeDistance)) * inside;

   vec3 cyan = vec3(0.12, 0.95, 1.0);
   vec3 pink = vec3(1.0, 0.20, 0.65);

   vec3 rimColor = mix(
     cyan,
     pink,
     toseeHash(cell + vec2(5.4, 28.6))
   );

   result.rgb = clamp(
     result.rgb + rimColor * edge * flare * glow * oldMask * 0.60,
     0.0,
     1.0
   );

   return result;
 }
