# Contributing to gl-transitions

Thanks for your interest in contributing! Here's what you need to know.

## Adding a new transition

### File structure

Place your transition as a **single `.glsl` file** directly in the `transitions/` folder:

```
transitions/MyTransition.glsl    <-- correct
transitions/MyTransition.glsl/MyTransition.glsl   <-- WRONG (GitHub web UI sometimes creates this)
```

Use UTF-8 and LF (Unix) line endings; CI checks both with `npm run lint`.

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

### Description, tags and parameter hints (recommended)

Help people find and use your transition by describing it:

```glsl
// Author: Your Name
// License: MIT
// Description: A ragged left-to-right wipe, as if the image was blown away by the wind
// Tags: wipe, horizontal, noise

// @range(0, 1) Width of the ragged edge
uniform float size; // = 0.2
// @param Wipe from right to left instead
uniform bool reversed; // = false
```

- Put hints (`@range(min, max[, step])`, `@color`, `@param`) on the line **above** the uniform, never after the default value.
- Tags are lowercase; use dashes for multiple words (`zoom-in`).

See [Transition metadata](README.md#transition-metadata-optional) for the full syntax.

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

## Development

The repository tooling lives in `scripts/` (see [scripts/README.md](scripts/README.md)). It uses Node 22 (`.nvmrc`), ES modules (`.mjs`) and a single `package.json` at the root:

```sh
npm ci
npm test
npm run lint
npm run format
npm run validate -- -t transitions/MyTransition.glsl
```
