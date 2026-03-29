# Contributing to gl-transitions

Thanks for your interest in contributing! Here's what you need to know.

## Adding a new transition

### File structure

Place your transition as a **single `.glsl` file** directly in the `transitions/` folder:

```
transitions/MyTransition.glsl    <-- correct
transitions/MyTransition.glsl/MyTransition.glsl   <-- WRONG (GitHub web UI sometimes creates this)
```

If you use the GitHub web UI to create a file, make sure you type the full path `transitions/MyTransition.glsl` in the filename field, not just `MyTransition.glsl` after navigating into the `transitions/` folder.

### File format

Your `.glsl` file must include:

```glsl
// Author: Your Name
// License: MIT

// Optional: uniform parameters with defaults
uniform float myParam; // = 1.0

vec4 transition(vec2 uv) {
  return mix(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
```

### Required elements

1. **Author comment** on the first line: `// Author: Your Name`
2. **License comment** on the second line: `// License: MIT` (MIT is strongly preferred)
3. **`transition` function**: `vec4 transition(vec2 uv)` - the entry point
4. Use **`getFromColor(uv)`** and **`getToColor(uv)`** to sample textures (not `texture2D`)
5. Use the contextual **`progress`** variable (0.0 to 1.0)

### Transition parameters

Define parameters as uniforms with commented default values (GLSL 120 / WebGL 1 does not support uniform initialization):

```glsl
uniform float speed; // = 1.0
uniform vec2 direction; // = vec2(1.0, 0.0)
uniform bool invert; // = false
```

### Naming conventions

- Use **PascalCase** for transition names (e.g., `StarWipe.glsl`, `CrossZoom.glsl`)
- Choose a **descriptive name** that reflects what the transition does
- Avoid generic names like `fragment.glsl` or `effect.glsl`

### Before submitting

- Check that your transition is not a duplicate of an existing one
- Test your transition at https://gl-transitions.com/editor if possible
- Adding customizable uniform parameters is encouraged but not mandatory
- Avoid using `#ifdef GL_ES` / `precision mediump float;` (the runtime handles this)

## Updating an existing transition

If you're modifying an existing transition, please explain the motivation in your PR description. Bug fixes and new optional parameters are welcome.

## Spec reference

See the [GL Transition Specification v1](README.md#gl-transition-specification-v1) in the README for full technical details.
