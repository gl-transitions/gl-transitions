//! Typed transition parameters and their values.

use std::fmt;

use crate::Transition;

/// The GLSL type of a parameter (`uniform <type> <name>;` in the transition).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum ParamType {
    /// `float`
    Float,
    /// `vec2`
    Vec2,
    /// `vec3`
    Vec3,
    /// `vec4`
    Vec4,
    /// `int`
    Int,
    /// `ivec2`
    IVec2,
    /// `ivec3`
    IVec3,
    /// `ivec4`
    IVec4,
    /// `bool`: an `int` (0 or 1) in SkSL, WGSL and Metal
    Bool,
}

impl ParamType {
    /// The GLSL name of the type, e.g. `"vec2"`.
    pub fn glsl_name(self) -> &'static str {
        match self {
            ParamType::Float => "float",
            ParamType::Vec2 => "vec2",
            ParamType::Vec3 => "vec3",
            ParamType::Vec4 => "vec4",
            ParamType::Int => "int",
            ParamType::IVec2 => "ivec2",
            ParamType::IVec3 => "ivec3",
            ParamType::IVec4 => "ivec4",
            ParamType::Bool => "bool",
        }
    }

    /// Number of scalar components (1 for `float`, `int` and `bool`).
    pub fn components(self) -> usize {
        match self {
            ParamType::Float | ParamType::Int | ParamType::Bool => 1,
            ParamType::Vec2 | ParamType::IVec2 => 2,
            ParamType::Vec3 | ParamType::IVec3 => 3,
            ParamType::Vec4 | ParamType::IVec4 => 4,
        }
    }
}

impl fmt::Display for ParamType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.glsl_name())
    }
}

/// A parameter value, typed like the uniform it sets.
#[derive(Clone, Copy, Debug, PartialEq)]
#[non_exhaustive]
pub enum Value {
    /// `float`
    Float(f32),
    /// `vec2`
    Vec2([f32; 2]),
    /// `vec3`
    Vec3([f32; 3]),
    /// `vec4`
    Vec4([f32; 4]),
    /// `int`
    Int(i32),
    /// `ivec2`
    IVec2([i32; 2]),
    /// `ivec3`
    IVec3([i32; 3]),
    /// `ivec4`
    IVec4([i32; 4]),
    /// `bool`
    Bool(bool),
}

impl Value {
    /// The type of the uniform this value sets.
    pub fn ty(&self) -> ParamType {
        match self {
            Value::Float(_) => ParamType::Float,
            Value::Vec2(_) => ParamType::Vec2,
            Value::Vec3(_) => ParamType::Vec3,
            Value::Vec4(_) => ParamType::Vec4,
            Value::Int(_) => ParamType::Int,
            Value::IVec2(_) => ParamType::IVec2,
            Value::IVec3(_) => ParamType::IVec3,
            Value::IVec4(_) => ParamType::IVec4,
            Value::Bool(_) => ParamType::Bool,
        }
    }

    /// The value as the generated SkSL, WGSL and Metal shaders declare it: `bool` becomes an
    /// `Int` (0 or 1), everything else is unchanged.
    pub fn as_shader_value(self) -> Value {
        match self {
            Value::Bool(b) => Value::Int(i32::from(b)),
            v => v,
        }
    }

    /// Appends the value's components, 4 bytes each, with `to_bytes` (native or little endian).
    pub(crate) fn write(&self, out: &mut Vec<u8>, f: fn(f32) -> [u8; 4], i: fn(i32) -> [u8; 4]) {
        match *self {
            Value::Float(v) => out.extend(f(v)),
            Value::Vec2(v) => v.iter().for_each(|&c| out.extend(f(c))),
            Value::Vec3(v) => v.iter().for_each(|&c| out.extend(f(c))),
            Value::Vec4(v) => v.iter().for_each(|&c| out.extend(f(c))),
            Value::Int(v) => out.extend(i(v)),
            Value::IVec2(v) => v.iter().for_each(|&c| out.extend(i(c))),
            Value::IVec3(v) => v.iter().for_each(|&c| out.extend(i(c))),
            Value::IVec4(v) => v.iter().for_each(|&c| out.extend(i(c))),
            Value::Bool(v) => out.extend(i(i32::from(v))),
        }
    }
}

macro_rules! from {
    ($($t:ty => $variant:ident),* $(,)?) => {
        $(impl From<$t> for Value {
            fn from(v: $t) -> Self {
                Value::$variant(v)
            }
        })*
    };
}
from!(
    f32 => Float, [f32; 2] => Vec2, [f32; 3] => Vec3, [f32; 4] => Vec4,
    i32 => Int, [i32; 2] => IVec2, [i32; 3] => IVec3, [i32; 4] => IVec4,
    bool => Bool,
);

/// A parameter of a transition: a uniform the user can set, with its default and UI hints.
#[derive(Clone, Copy, Debug, PartialEq)]
#[non_exhaustive]
pub struct Param {
    /// The uniform's name.
    pub name: &'static str,
    /// The uniform's GLSL type.
    pub ty: ParamType,
    /// The value used when none is given (`// = value` in the transition).
    pub default: Value,
    /// Suggested lower bound for a UI.
    pub min: Option<f32>,
    /// Suggested upper bound for a UI.
    pub max: Option<f32>,
    /// Suggested UI step.
    pub step: Option<f32>,
    /// The value is a color (RGB or RGBA in 0..1).
    pub color: bool,
    /// What the parameter does.
    pub description: Option<&'static str>,
}

/// Why a parameter value was refused.
#[derive(Clone, Debug, PartialEq)]
#[non_exhaustive]
pub enum ParamError {
    /// The transition has no parameter with this name.
    Unknown {
        /// The transition's name.
        transition: &'static str,
        /// The name that was given.
        name: String,
    },
    /// The value's type is not the parameter's.
    WrongType {
        /// The parameter's name.
        name: &'static str,
        /// The parameter's type.
        expected: ParamType,
        /// The type of the value that was given.
        found: ParamType,
    },
}

impl fmt::Display for ParamError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ParamError::Unknown { transition, name } => {
                write!(f, "transition `{transition}` has no parameter `{name}`")
            }
            ParamError::WrongType {
                name,
                expected,
                found,
            } => {
                write!(f, "parameter `{name}` is a {expected}, got a {found}")
            }
        }
    }
}

impl std::error::Error for ParamError {}

/// The values of every parameter of one transition, starting from the defaults
/// ([`Transition::default_params`]). Turns them, with `progress`, into the uniform data of each
/// target.
#[derive(Clone, Debug)]
pub struct ParamValues {
    transition: &'static Transition,
    values: Vec<Value>,
}

impl ParamValues {
    pub(crate) fn new(transition: &'static Transition) -> Self {
        ParamValues {
            transition,
            values: transition.params().iter().map(|p| p.default).collect(),
        }
    }

    /// The transition these values are for.
    pub fn transition(&self) -> &'static Transition {
        self.transition
    }

    /// The current value of a parameter.
    pub fn get(&self, name: &str) -> Option<Value> {
        self.index(name).map(|i| self.values[i])
    }

    /// Sets a parameter. The value must have the parameter's type.
    pub fn set(&mut self, name: &str, value: impl Into<Value>) -> Result<&mut Self, ParamError> {
        let value = value.into();
        let i = self.index(name).ok_or_else(|| ParamError::Unknown {
            transition: self.transition.name(),
            name: name.to_owned(),
        })?;
        let param = &self.transition.params()[i];
        if value.ty() != param.ty {
            return Err(ParamError::WrongType {
                name: param.name,
                expected: param.ty,
                found: value.ty(),
            });
        }
        self.values[i] = value;
        Ok(self)
    }

    /// [`set`](Self::set), by value, for chaining.
    pub fn with(mut self, name: &str, value: impl Into<Value>) -> Result<Self, ParamError> {
        self.set(name, value)?;
        Ok(self)
    }

    /// Every parameter with its current value, in declaration order.
    pub fn iter(&self) -> impl Iterator<Item = (&'static Param, Value)> + '_ {
        self.transition
            .params()
            .iter()
            .zip(self.values.iter().copied())
    }

    fn index(&self, name: &str) -> Option<usize> {
        self.transition.params().iter().position(|p| p.name == name)
    }

    /// The uniform data of the SkSL runtime effect ([`Transition::sksl`]), for
    /// `SkRuntimeEffect::makeShader` (skia-safe: `RuntimeEffect::make_shader`): `_resolution`,
    /// `progress`, `ratio` (`width / height`), then every parameter, packed in declaration order
    /// in native byte order. `width` and `height` are the size of the drawn area in pixels.
    pub fn sksl_uniforms(&self, progress: f32, width: f32, height: f32) -> Vec<u8> {
        let mut out = Vec::with_capacity(16 + 16 * self.values.len());
        for v in [width, height, progress, width / height] {
            out.extend(v.to_ne_bytes());
        }
        for v in &self.values {
            v.write(&mut out, f32::to_ne_bytes, i32::to_ne_bytes);
        }
        out
    }

    /// The uniform buffer of the WGSL and Metal shaders ([`Transition::wgsl`],
    /// [`Transition::msl`]): `progress`, `ratio`, then every parameter at the offsets of
    /// [`Transition::uniform_layout`], little endian. `None` when the transition has no WGSL or
    /// Metal version.
    ///
    /// The buffer is `layout.size` bytes, but at least 16: some WebGPU backends refuse smaller
    /// uniform bindings (the gl-transitions WebGPU renderer pads the same way).
    pub fn uniform_buffer(&self, progress: f32, ratio: f32) -> Option<Vec<u8>> {
        let layout = self.transition.uniform_layout()?;
        let mut out = vec![0u8; layout.size.max(16)];
        let mut put = |name: &str, value: Value| {
            if let Some(field) = layout.fields.iter().find(|f| f.name == name) {
                let mut bytes = Vec::with_capacity(16);
                value.write(&mut bytes, f32::to_le_bytes, i32::to_le_bytes);
                out[field.offset..field.offset + bytes.len()].copy_from_slice(&bytes);
            }
        };
        put("progress", Value::Float(progress));
        put("ratio", Value::Float(ratio));
        for (param, value) in self.iter() {
            put(param.name, value);
        }
        Some(out)
    }
}

/// Where each value goes in the uniform buffer of the WGSL and Metal shaders (std140 / WGSL
/// uniform layout rules), from the npm package's `layouts.json`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[non_exhaustive]
pub struct UniformLayout {
    /// Size of the buffer in bytes.
    pub size: usize,
    /// `progress`, `ratio`, then every parameter (`bool` ones are stored as `i32`).
    pub fields: &'static [UniformField],
}

/// One value of a [`UniformLayout`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[non_exhaustive]
pub struct UniformField {
    /// The uniform's name.
    pub name: &'static str,
    /// Its GLSL type.
    pub ty: ParamType,
    /// Offset in bytes from the start of the buffer.
    pub offset: usize,
}
