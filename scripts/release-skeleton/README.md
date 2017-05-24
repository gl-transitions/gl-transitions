# gl-transitions

> The open collection of GL Transitions.

This package exposes an Array<Transition> auto-generated from the [GitHub repository](https://github.com/gltransitions/gl-transitions).

a Transition is an object with following shape:

```js
{
  name: string,
  author: string,
  license: string,
  glsl: string,
  defaultParams: { [key: string]: mixed },
  paramsTypes: { [key: string]: string },
  createdAt: string,
  updatedAt: string,
}
```

For more information, please checkout https://github.com/gltransitions/gl-transitions

## Install

**with NPM:**

```sh
yarn add gl-transitions
```

```js
import GLTransitions from "gl-transitions";
```

**dist script:**

```
https://unpkg.com/gl-transitions@0/gl-transitions.js
```

```js
const GLTransitions = window.GLTransitions
```

**vanilla JSON:**

```
https://unpkg.com/gl-transitions@0/gl-transitions.json
```
