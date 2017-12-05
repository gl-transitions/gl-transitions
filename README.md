
- Website: https://gl-transitions.com  *( alternative hosting: https://gl-transitions.surge.sh/ )*
- NPM package: https://www.npmjs.com/package/gl-transitions
- Libraries for gl-transitions: https://github.com/gre/gl-transition-libs

---

Each commit that gets to [gl-transitions/gl-transitions](https://github.com/gl-transitions/gl-transitions)'s master automatically generate a new npm minor release.

 [![npm version](https://badge.fury.io/js/gl-transitions.svg)](https://badge.fury.io/js/gl-transitions) [![Build Status](https://travis-ci.org/gl-transitions/gl-transitions.svg?branch=master)](https://travis-ci.org/gl-transitions/gl-transitions)

<img src="https://camo.githubusercontent.com/c42ecc6197b0f51a106fb50723f9bc6d2e1f925c/687474703a2f2f692e696d6775722e636f6d2f74573331704a452e676966" /><img src="https://camo.githubusercontent.com/7e34cd12d5a9afa94f470395b04b0914c978ce01/687474703a2f2f692e696d6775722e636f6d2f555a5a727775552e676966" /><img src="https://camo.githubusercontent.com/0456d4ed8753fbce027f1174dc8b22da548eeade/687474703a2f2f692e696d6775722e636f6d2f654974426a33582e676966" />

---

# GL Transition Specification v1

**NB. This is a technical documentation, for more informal information, please see https://gl-transitions.com/ homepage.**

This document specifies GL Transition Specification **v1**, `1` as in `gl-transitions @ 1` (consistently to the NPM package major). For any breaking changes in this specification, semver will be respected and the major will get bumped.

## What is a transition?

A Transition is an animation that smoothly animates the intermediary steps between 2 textures: `from` and `to`. The step is specified by a `progress` value that moves from `0.0` to `1.0`.

> important feature to respect: When progress is 0.0, exclusively the `from` texture must be rendered. When progress is 1.0, exclusively the `to` texture must be rendered.

## GL Transition

```glsl
// transition of a simple fade.
vec4 transition (vec2 uv) {
  return mix(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
```

A GL Transition is a GLSL code that implements a `transition` function which takes a `vec2 uv` pixel position and returns a `vec4` color. This color represents the mix of the `from` to the `to` textures based on the variation of a contextual `progress` value from `0.0` to `1.0`.

### Contextual variables

- `progress` (float): a value that **moves from 0.0 to 1.0** during the transition.
- `ratio` (float): the ratio of the viewport. It equals `width / height`. *(width and height are not exposed because you don't need them. A transition code should be scalable to any size. ratio can still be used to preserve some shape ratio, e.g. you want to draw squares)*

### Contextual functions

- `vec4 getFromColor(vec2 uv)`: lookup the "from" texture at a given uv coordinate.
- `vec4 getToColor(vec2 uv)`: lookup the "to" texture at a given uv coordinate.

> don't directly use `texture2D` to get a texture pixel out of from and to textures. Instead, use `getFromColor(vec2)` and `getToColor(vec2)`. That way, the "implementer" can properly implement ratio preserving support as well as chosing a different color for the "out of bound" case.

### Transition parameters

Transition parameters are parameters than the final user can set to tweak the transition. They are constant over a full run of a transition *(no parameter changes when progress moves from 0.0 to 1.0)*.

> any constant you define in your transitions are potential parameters to expose.

When you define a transition parameter, you must also define a default value that will get set in case the final user didn't provided it. It's unfortunately not possible to initialize a uniform in GLSL 120 (WebGL 1) but we support commented code `// = value`

Examples:

```glsl
uniform float foo; // = 42.0
uniform vec2 foo; // = vec2(42.0, 42.0)
```

The following variants are also supported:


```glsl
uniform float foo/* = 42.0 */;
uniform vec2 foo /*= vec2(42.0, 42.0)*/, bar /* = vec2(1.) */;
uniform vec2 foo, bar; // = vec2(1.0, 2.0); // both at the same time ! (needs a ';' if you have this second //, like usual glsl code)
```


# `gl-transitions`

> TBD this is not finished to be written. just keeping these notes around...

- If we have duplicated transitions or one transition is more generic than another one, we don't necessary drop the less generic one: it might be more performant and might fit for some users. We also want to keep backward compat'. if we still want to drop it, what we will do is to deprecate it and drop it at the next major bump.
