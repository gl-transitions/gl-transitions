// author: Gunnar Roth
// based on work from natewave
// license: MIT
uniform bool transparentMode; // = false
vec4 transition(vec2 p) {
  vec2 block = floor(p.xy / vec2(16));
  vec2 uv_noise = block / vec2(64);
  uv_noise += floor(vec2(progress) * vec2(1200.0, 3500.0)) / vec2(64);
  vec2 dist = progress > 0.0 ? (fract(uv_noise) - 0.5) * 0.3 *(1.0 -progress) : vec2(0.0);
  vec2 red = p + dist * 0.2;
  vec2 green = p + dist * .3;
  vec2 blue = p + dist * .5;

  float alpha = 1.0;
  if (transparentMode) {
    // blend all the alphas...
    alpha = (mix(getFromColor(red), getToColor(red), progress).a + mix(getFromColor(green), getToColor(green), progress).a + mix(getFromColor(blue), getToColor(blue), progress).a) / 3.0;
  }
  return vec4(mix(getFromColor(red), getToColor(red), progress).r,mix(getFromColor(green), getToColor(green), progress).g,mix(getFromColor(blue), getToColor(blue), progress).b,alpha);
}

