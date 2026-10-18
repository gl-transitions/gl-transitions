// The README example uses the SkSL and WGSL sources: only a doctest when they are compiled in.
#![cfg_attr(all(feature = "sksl", feature = "wgsl"), doc = include_str!("../README.md"))]
#![cfg_attr(
    not(all(feature = "sksl", feature = "wgsl")),
    doc = "The gl-transitions collection: shader sources, metadata and typed parameters (see the README)."
)]
#![forbid(unsafe_code)]
#![warn(missing_docs)]

mod params;

pub use params::{Param, ParamError, ParamType, ParamValues, UniformField, UniformLayout, Value};

/// A transition of the collection: its metadata, parameters and shader sources.
///
/// Every transition is a `static`: get them with [`all`] or [`get`].
#[derive(Debug)]
pub struct Transition {
    name: &'static str,
    author: &'static str,
    license: &'static str,
    description: Option<&'static str>,
    tags: &'static [&'static str],
    params: &'static [Param],
    textures: &'static [&'static str],
    glsl: &'static str,
    #[cfg(feature = "sksl")]
    sksl: Option<&'static str>,
    #[cfg(feature = "glsl3")]
    glsl3: Option<&'static str>,
    #[cfg(feature = "wgsl")]
    wgsl: Option<&'static str>,
    #[cfg(feature = "msl")]
    msl: Option<&'static str>,
    uniform_layout: Option<UniformLayout>,
}

impl Transition {
    /// Stable identifier, e.g. `"crosswarp"` (case-sensitive, also the file name).
    pub fn name(&self) -> &'static str {
        self.name
    }

    /// Author, as written in the transition's header.
    pub fn author(&self) -> &'static str {
        self.author
    }

    /// License of the transition's source, e.g. `"MIT"`.
    pub fn license(&self) -> &'static str {
        self.license
    }

    /// One sentence describing what the transition looks like.
    pub fn description(&self) -> Option<&'static str> {
        self.description
    }

    /// Lowercase keywords such as `"wipe"`, `"zoom"` or `"3d"`.
    pub fn tags(&self) -> &'static [&'static str] {
        self.tags
    }

    /// Parameters in declaration order.
    pub fn params(&self) -> &'static [Param] {
        self.params
    }

    /// A parameter by name.
    pub fn param(&self, name: &str) -> Option<&'static Param> {
        self.params.iter().find(|p| p.name == name)
    }

    /// Every parameter set to its default, to change with [`ParamValues::set`] and turn into
    /// uniform data.
    pub fn default_params(&'static self) -> ParamValues {
        ParamValues::new(self)
    }

    /// Extra images the transition samples besides the two it transitions between (e.g.
    /// `"displacementMap"`), in the order the shaders bind them.
    pub fn textures(&self) -> &'static [&'static str] {
        self.textures
    }

    /// The original source (GL Transition Specification v1): `vec4 transition(vec2 uv)`, to wrap
    /// with `getFromColor`, `getToColor`, `progress` and `ratio`.
    pub fn glsl(&self) -> &'static str {
        self.glsl
    }

    /// A complete SkSL runtime effect, for Skia (skia-safe). Children: `_from`, `_to`, then one
    /// per [`textures`](Self::textures) entry, sampled at the output size; uniforms: see
    /// [`ParamValues::sksl_uniforms`]. Returns premultiplied colors.
    #[cfg(feature = "sksl")]
    pub fn sksl(&self) -> Option<&'static str> {
        self.sksl
    }

    /// The GLSL ES 3.00 version (WebGL 2, OpenGL ES 3): like [`glsl`](Self::glsl), with
    /// `texture()` instead of `texture2D()`. The host provides the wrapper.
    #[cfg(feature = "glsl3")]
    pub fn glsl3(&self) -> Option<&'static str> {
        self.glsl3
    }

    /// A complete WGSL fragment shader (entry point `main`), for wgpu, Bevy or WebGPU.
    ///
    /// Bindings in group 0: 0 the uniform buffer ([`ParamValues::uniform_buffer`]), 1 a sampler
    /// (linear, clamp to edge), 2 the `from` image, 3 the `to` image, then one per
    /// [`textures`](Self::textures) entry. Input `@location(0)` is the uv in `[0, 1]` with a
    /// bottom-left origin; the output is straight (unpremultiplied) RGBA.
    #[cfg(feature = "wgsl")]
    pub fn wgsl(&self) -> Option<&'static str> {
        self.wgsl
    }

    /// A complete Metal Shading Language fragment shader (entry point `main_`), with the same
    /// interface as [`wgsl`](Self::wgsl): `buffer(0)`, `sampler(0)`, `texture(0)` = from,
    /// `texture(1)` = to, then the extra textures.
    #[cfg(feature = "msl")]
    pub fn msl(&self) -> Option<&'static str> {
        self.msl
    }

    /// The uniform buffer layout of the WGSL and Metal shaders.
    pub fn uniform_layout(&self) -> Option<&UniformLayout> {
        self.uniform_layout.as_ref()
    }
}

include!(concat!(env!("CARGO_MANIFEST_DIR"), "/generated/catalog.rs"));

/// Every transition, sorted by name (byte order: uppercase first).
pub fn all() -> &'static [Transition] {
    TRANSITIONS
}

/// A transition by its exact [`name`](Transition::name).
pub fn get(name: &str) -> Option<&'static Transition> {
    TRANSITIONS
        .binary_search_by(|t| t.name.cmp(name))
        .ok()
        .map(|i| &TRANSITIONS[i])
}

#[cfg(test)]
mod tests;
