// Author: Nicolaj Kirkegaard Nielsen
// License: MIT

vec4 transition (vec2 uv) {
  if ( uv.y < 1.0  - progress ) {
    return getFromColor(vec2(uv.x, (uv.y + progress )));
  } else {
    return getToColor(vec2(uv.x, (uv.y + progress - 1.0 )));
  }
}
