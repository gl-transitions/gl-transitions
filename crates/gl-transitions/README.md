# gl-transitions

The [gl-transitions](https://gl-transitions.com) collection for Rust: 100+ transitions between two images, as ready-to-use shader sources with their metadata, typed parameters and uniform layouts. No dependencies, no GPU code: bring your own renderer.

| Accessor | Language | For | Cargo feature |
|---|---|---|---|
| `glsl()` | GLSL ([spec v1](https://github.com/gl-transitions/gl-transitions#gl-transition-specification-v1)), the original | OpenGL, WebGL with your wrapper | always |
| `sksl()` | SkSL runtime effect | Skia: [skia-safe](https://crates.io/crates/skia-safe), [fframes](https://github.com/dmtrKovalenko/fframes) | `sksl` |
| `wgsl()` | WGSL fragment shader | wgpu, Bevy | `wgsl` |
| `msl()` | Metal fragment shader | Metal | `msl` |
| `glsl3()` | GLSL ES 3.00 | OpenGL ES 3, WebGL 2 | `glsl3` |

All features are on by default; turn off the ones you don't use to keep their sources out of your binary (`default-features = false, features = ["sksl"]`). The sources are the ones of the [`gl-transitions` npm package](https://www.npmjs.com/package/gl-transitions) version `CATALOG_VERSION`, where each target's contract is documented and checked against the GLSL reference renders.

## Example

```rust
let transition = gl_transitions::get("directionalwarp").expect("in the collection");
println!("{} by {}: {:?}", transition.name(), transition.author(), transition.description());

// Parameters start from their defaults and are type-checked.
let mut params = transition.default_params();
params.set("direction", [1.0, 0.0])?;

// SkSL: children `_from`, `_to` (+ extra textures), uniforms packed for Skia.
let sksl: &str = transition.sksl().unwrap();
let uniforms: Vec<u8> = params.sksl_uniforms(0.5, 1920.0, 1080.0);

// WGSL: a uniform buffer laid out as the shader declares it (at least 16 bytes).
let wgsl: &str = transition.wgsl().unwrap();
let buffer: Vec<u8> = params.uniform_buffer(0.5, 1920.0 / 1080.0).unwrap();
assert!(buffer.len() >= transition.uniform_layout().unwrap().size);
# let _ = (sksl, uniforms, wgsl);
# Ok::<(), gl_transitions::ParamError>(())
```

With skia-safe, draw a transition between two images (`from`, `to`) of the output size:

```rust,ignore
let effect = skia_safe::RuntimeEffect::make_for_shader(transition.sksl().unwrap(), None)?;
let data = skia_safe::Data::new_copy(&params.sksl_uniforms(progress, width, height));
let children = [from.to_shader(None, sampling, None).unwrap().into(), to.to_shader(None, sampling, None).unwrap().into()];
paint.set_shader(effect.make_shader(data, &children, None));
canvas.draw_rect(Rect::from_wh(width, height), &paint);
```

[`examples/fframes`](https://github.com/gl-transitions/gl-transitions/tree/master/examples/fframes) draws transitions in an [fframes](https://github.com/dmtrKovalenko/fframes) video this way. Hosts that set uniforms by name (fframes, OpenGL) iterate over `params.iter()`; `Value::as_shader_value` turns `bool` values into the `int` the SkSL, WGSL and Metal shaders declare.

## Versions

The crate follows its own semver (0.x while the API settles); `gl_transitions::CATALOG_VERSION` says which npm release the transitions come from. Each release of the npm package publishes a patch release of the crate with its transitions, so `gl-transitions = "0.1"` keeps getting new ones; the changes are in [CHANGELOG.md](https://github.com/gl-transitions/gl-transitions/blob/master/crates/gl-transitions/CHANGELOG.md).

This crate is built in the [gl-transitions repository](https://github.com/gl-transitions/gl-transitions/tree/master/crates/gl-transitions). Each transition keeps the license of its source (`license()`): MIT for nearly all of them, BSD for a few, whose notices and conditions are in `generated/LICENSES.md` of the crate. A transition a target's compiler rejected has no source for that target (`None`).
