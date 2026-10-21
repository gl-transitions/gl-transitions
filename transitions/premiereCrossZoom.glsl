// Author: Jonatha Santos
// License: MIT

vec2 zoom(vec2 uv, float amount) {
    vec2 center = vec2(0.5);
    // When amount is large, we are zoomed in.
    // We divide by amount to zoom in.
    return (uv - center) / amount + center;
}

vec4 transition(vec2 uv) {
    vec4 color;
    
    // First half: Zoom in on 'from'
    if (progress < 0.5) {
        // progress * 2.0 goes from 0.0 to 1.0
        // We make the zoom factor go from 1.0 to 20.0
        float scale = 1.0 + (progress * 2.0) * 19.0; 
        vec2 zoomedUv = zoom(uv, scale);
        
        // If the coordinate is outside 0-1, it means we've zoomed past the edges
        if (zoomedUv.x < 0.0 || zoomedUv.x > 1.0 || zoomedUv.y < 0.0 || zoomedUv.y > 1.0) {
            color = vec4(0.0, 0.0, 0.0, 1.0);
        } else {
            color = getFromColor(zoomedUv);
        }
    } 
    // Second half: Zoom out on 'to'
    else {
        // (progress - 0.5) * 2.0 goes from 0.0 to 1.0
        // We make the zoom factor go from 20.0 down to 1.0
        float scale = 20.0 - ((progress - 0.5) * 2.0) * 19.0;
        vec2 zoomedUv = zoom(uv, scale);
        
        if (zoomedUv.x < 0.0 || zoomedUv.x > 1.0 || zoomedUv.y < 0.0 || zoomedUv.y > 1.0) {
            color = vec4(0.0, 0.0, 0.0, 1.0);
        } else {
            color = getToColor(zoomedUv);
        }
    }
    
    return color;
}
