// Author: OllyOllyOlly
// License: MIT

vec2 zoom(vec2 uv, float amount) {
  return 0.5 + ((uv - 0.5) * (1.0-amount));
}

vec4 transition (vec2 uv) {
  if(progress < 0.49) {
    return mix(
      getFromColor(zoom(uv, smoothstep(0.0, 1.0, progress * 2.0))),
      getToColor(uv),
      smoothstep(0.8, 1.0, progress)
    );
  } else if (progress < 0.51) {
    return mix(
    getFromColor(zoom(uv, smoothstep(0.0, 1.0, progress * 2.0))),
    getToColor(zoom(uv, smoothstep(0.0, 1.0, (1.0 - progress) * 2.0))),
    smoothstep(0.8, 1.0, progress)
  );

  } else {
    return mix(
      getToColor(zoom(uv, smoothstep(0.0, 1.0, (1.0 - progress) * 2.0))),
      getFromColor(uv),
      smoothstep(0.8, 1.0, 1.0 - progress)
    );
  }
}
