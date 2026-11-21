// Author: Gilad Levi
// License: MIT
// Description: Soft diagonal ribbons peel the outgoing image away in a flowing aurora-like sweep. The bands bend, shimmer, and reveal the incoming image beneath them.
// Tags: ribbon, wave, diagonal, silk, aurora, fashion, elegant, cinematic

// @range(0.03, 0.18) Height of each ribbon band relative to the frame
uniform float bandSize; // = 0.075
// @range(0.0, 1.5) Strength of the ribbon bending distortion
uniform float bend; // = 0.65
// @range(0.0, 1.0) Softness of the ribbon edges
uniform float softness; // = 0.35
// @range(0.0, 1.0) Strength of the glow on active ribbon edges
uniform float glow; // = 0.55
// @range(0.0, 1.0) 0 = mostly horizontal sweep, 1 = strongly diagonal sweep
uniform float diagonal; // = 0.80

// ------------------------------------------------------------
// Utility: stable pseudo-random function
// Gives each ribbon slightly different timing and motion
// ------------------------------------------------------------
float hash11(float n) {
  return fract(sin(n) * 43758.5453123);
}

// ------------------------------------------------------------
// Main transition
// uv        = current pixel coordinates (0..1)
// progress  = transition progress (0..1)
// ratio     = width / height
// getFromColor(uv) = current slide image
// getToColor(uv)   = next slide image
// ------------------------------------------------------------
vec4 transition(vec2 uv) {
  // Safety: show exact source/target image at the beginning/end
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  // ----------------------------------------------------------
  // 1) Convert coordinates to aspect-correct space
  // This keeps the ribbon geometry visually balanced
  // even on wide slider canvases
  // ----------------------------------------------------------
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);

  // ----------------------------------------------------------
  // 2) Build a diagonal sweep direction
  // Higher "diagonal" means the transition travels more
  // diagonally across the frame instead of purely sideways
  // ----------------------------------------------------------
  float sweepCoord = mix(p.x, 0.70 * p.x - 0.70 * p.y, diagonal);

  // ----------------------------------------------------------
  // 3) Create repeating ribbon bands
  // Each band gets a unique ID so we can vary its motion/timing
  // ----------------------------------------------------------
  float size = max(bandSize, 0.01);
  float bandId = floor((p.y + 0.5) / size);
  float localY = mod(p.y + 0.5, size) / size;

  // ----------------------------------------------------------
  // 4) Per-band randomness
  // This prevents the effect from feeling too mechanical
  // ----------------------------------------------------------
  float r1 = hash11(bandId * 13.17);
  float r2 = hash11(bandId * 29.73);
  float r3 = hash11(bandId * 47.91);

  // ----------------------------------------------------------
  // 5) Start time for each band
  // Bands are triggered by the diagonal sweep, but slightly
  // staggered using randomness for a more organic motion
  // ----------------------------------------------------------
  float start = 0.18 + 0.58 * (sweepCoord / ratio + 0.5) + 0.10 * (r1 - 0.5);
  float t = clamp((progress - start) / 0.28, 0.0, 1.0);

  // ----------------------------------------------------------
  // 6) Ribbon bending
  // While active, each ribbon bends sideways and slightly
  // flutters, like a soft strip being pulled through air
  // ----------------------------------------------------------
  float wave = sin(localY * 3.14159265);
  float flutter = sin((localY * 6.2831853) + r2 * 6.2831853);
  float shiftX = (0.20 + 0.35 * r2) * bend * t * wave;
  shiftX += 0.08 * bend * t * flutter;

  // Small vertical drift so the ribbons feel more alive
  float shiftY = (r3 - 0.5) * 0.04 * bend * t;

  vec2 distortedUV = uv + vec2(shiftX / ratio, shiftY);

  // ----------------------------------------------------------
  // 7) Old image visibility mask
  // The outgoing image stays visible inside each ribbon while
  // the band is active, then fades away
  // ----------------------------------------------------------
  float edgeSoft = mix(0.02, 0.18, softness);
  float ribbonCore = smoothstep(0.0, edgeSoft, localY) *
                     (1.0 - smoothstep(1.0 - edgeSoft, 1.0, localY));

  float oldVisibility = (1.0 - smoothstep(0.35, 1.0, t)) * ribbonCore;

  // ----------------------------------------------------------
  // 8) Sample outgoing and incoming images
  // The outgoing image is slightly distorted by the ribbon bend
  // The incoming image stays stable underneath
  // ----------------------------------------------------------
  vec4 fromColor = getFromColor(clamp(distortedUV, 0.0, 1.0));
  vec4 toColor = getToColor(uv);

  vec4 color = mix(toColor, fromColor, oldVisibility);

  // ----------------------------------------------------------
  // 9) Add a soft highlight to the moving ribbon edges
  // This gives the effect a more premium, glossy feeling
  // ----------------------------------------------------------
  float edgeTop = 1.0 - smoothstep(0.0, 0.08, abs(localY - 0.0));
  float edgeBottom = 1.0 - smoothstep(0.0, 0.08, abs(localY - 1.0));
  float edge = max(edgeTop, edgeBottom);

  float activeGlow = edge * glow * sin(t * 3.14159265) * oldVisibility;

  // A cool-to-warm fashion-style glow blend
  vec3 glowColorA = vec3(0.12, 0.85, 1.0);
  vec3 glowColorB = vec3(1.0, 0.38, 0.72);
  vec3 glowColor = mix(glowColorA, glowColorB, r1);

  color.rgb += glowColor * activeGlow * 0.55;
  color.rgb = clamp(color.rgb, 0.0, 1.0);

  return color;
}
