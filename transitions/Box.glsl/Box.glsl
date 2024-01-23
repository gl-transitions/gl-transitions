// Author: lql
// License: MIT
uniform int rectIn; // =1
// center:0, left_top:1, left_bottom:2, right_top:3, right_bottom:4
uniform int location; // =0

vec4 transition(vec2 uv) {
    float p = rectIn == 1 ? 1.0 - progress : progress;
    float x1, y1, x2, y2;

    // Determine rectangle coordinates based on location
    if (location == 0) {
        x1 = y1 = 0.5 * (1.0 - p);
        x2 = y2 = 1.0 - x1;
    } else {
        // Calculate the x and y coordinates based on the location
        x1 = (location == 1 || location == 2) ? 0.0 : 1.0 - p;
        y1 = (location == 1 || location == 3) ? 1.0 - p : 0.0;
        x2 = (location == 1 || location == 2) ? p : 1.0;
        y2 = (location == 1 || location == 3) ? 1.0 : p;
    }

    // Determine if the point is inside the rectangle
    float in_rect = step(x1, uv.x) * step(uv.x, x2) * step(y1, uv.y) * step(uv.y, y2);
    in_rect = rectIn == 1 ? 1.0 - in_rect : in_rect;

    // Mix colors based on the in_rect value
    return mix(getFromColor(uv), getToColor(uv), in_rect);
}
