[![Build Status](https://travis-ci.org/gltransitions/gl-transitions.svg?branch=master)](https://travis-ci.org/gltransitions/gl-transitions)

Each commit that gets to master automatically generate a new npm minor release.

See https://www.npmjs.com/package/gl-transitions

# Specification

## What is a transition?

A Transition is an animation that smoothly animates the intermediary steps between 2 textures.

The step is specified by a `progress` value that moves from 0.0 to 1.0.

> important feature to respect: When progress is 0.0, exclusively the `from` texture must be rendered. When progress is 1.0, exclusively the `to` texture must be rendered.

## GL Transition

A GL Transition is defined in the GLSL language and implements a function `vec4 transition (vec2 uv)`. It takes the current coordinate position to render and returns the color of that pixel.

### Transition parameters

If you need extra parameters for a transition, don't define them as "constant", instead expose them as uniforms.
When you do so, define a default value following with a comment `// = value`

Examples:

```glsl
uniform float foo; // = 42.0
uniform vec2 foo; // = vec2(42.0, 42.0)
```

### Context

#### Variables in context (uniforms)

- `progress` float that **moves from 0.0 to 1.0**
- `ratio` a float equals to `width / height`. *(width and height are not available because your code should be scalable to any size, however you can use this ratio to preserve your ratio, e.g. you want to draw squares)*

#### extra functions

- `vec4 getFromColor(vec2 uv)`: lookup the "from" texture at a given uv coordinate.
- `vec4 getToColor(vec2 uv)`: lookup the "to" texture at a given uv coordinate.

> don't use directly `texture2D` to get a texture pixel out of from and to. Instead, use `getFromColor(vec2)` and `getToColor(vec2)`. That way, the "implementer" can properly implement ratio preserving support as well as chosing a different color for the "out of bound" case.
