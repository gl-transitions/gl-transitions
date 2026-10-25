// Author: lql
// License: MIT
// Description: A chessboard pattern of squares reveals the incoming image
// Tags: grid, squares, pattern

// @param Number of squares per row
uniform float grid_num; // = 10.0

vec4 transition(vec2 uv) {
    vec2 st = uv * grid_num;
    vec2 idx = floor(st);
    vec2 grid = fract(st);

    vec4 a = getFromColor(uv);
    vec4 b = getToColor(uv);

    float checker = mod(idx.x + idx.y, 2.0);
    float mixFactor;

    if (progress <= 0.5) {
        mixFactor = (checker > 0.5) ? step(grid.x, progress * 2.0) : 0.0;
    } else {
        mixFactor = (checker < 0.5) ? step(grid.x, (progress - 0.5) * 2.0) : 1.0;
    }

    return mix(a, b, mixFactor);
}
