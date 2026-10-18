//! Every embedded WGSL shader parses and validates with naga, and declares the bindings and
//! uniform layout the crate documents (what `ParamValues::uniform_buffer` writes).
#![cfg(feature = "wgsl")]

use naga::valid::{Capabilities, ValidationFlags, Validator};
use naga::{AddressSpace, ShaderStage, TypeInner};

#[test]
fn every_wgsl_shader_validates_with_the_documented_interface() {
    // A transition the npm build could not convert has no WGSL (compatibility.json): skipped.
    let shipped: Vec<_> = gl_transitions::all()
        .iter()
        .filter(|t| t.wgsl().is_some())
        .collect();
    assert!(!shipped.is_empty());
    let mut failures = Vec::new();
    for t in shipped {
        if let Err(e) = check(t) {
            failures.push(format!("{}: {e}", t.name()));
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

fn check(t: &gl_transitions::Transition) -> Result<(), String> {
    let source = t.wgsl().unwrap();
    let module = naga::front::wgsl::parse_str(source).map_err(|e| e.emit_to_string(source))?;
    Validator::new(ValidationFlags::all(), Capabilities::default())
        .validate(&module)
        .map_err(|e| e.emit_to_string(source))?;

    let entry = module
        .entry_points
        .iter()
        .find(|e| e.name == "main")
        .ok_or("no `main` entry point")?;
    if entry.stage != ShaderStage::Fragment {
        return Err("`main` is not a fragment shader".into());
    }

    // Bindings of group 0, by name.
    let mut textures = vec!["_from", "_to"];
    textures.extend(t.textures());
    let binding = |name: &str| {
        module
            .global_variables
            .iter()
            .find(|(_, v)| v.name.as_deref() == Some(name))
            .and_then(|(_, v)| v.binding.as_ref())
            .map(|b| (b.group, b.binding))
    };
    for (i, name) in textures.iter().enumerate() {
        if binding(name) != Some((0, 2 + i as u32)) {
            return Err(format!("texture `{name}` is not at binding {}", 2 + i));
        }
    }

    // The uniform buffer at binding 0 has the layout's fields at the layout's offsets.
    let layout = t.uniform_layout().ok_or("no uniform layout")?;
    let (_, uniforms) = module
        .global_variables
        .iter()
        .find(|(_, v)| v.space == AddressSpace::Uniform)
        .ok_or("no uniform buffer")?;
    if uniforms.binding.as_ref().map(|b| (b.group, b.binding)) != Some((0, 0)) {
        return Err("the uniform buffer is not at binding 0".into());
    }
    let TypeInner::Struct { members, span } = &module.types[uniforms.ty].inner else {
        return Err("the uniform buffer is not a struct".into());
    };
    let actual: Vec<(&str, usize)> = members
        .iter()
        .map(|m| (m.name.as_deref().unwrap_or(""), m.offset as usize))
        .collect();
    let expected: Vec<(&str, usize)> = layout.fields.iter().map(|f| (f.name, f.offset)).collect();
    // naga appends `_` to names that are WGSL keywords (the `type` parameter is `type_`).
    let same = actual.len() == expected.len()
        && actual
            .iter()
            .zip(&expected)
            .all(|((a, ao), (e, eo))| ao == eo && (a == e || a.strip_suffix('_') == Some(e)));
    if !same {
        return Err(format!(
            "uniform fields {actual:?}, layout says {expected:?}"
        ));
    }
    if (*span as usize) > layout.size {
        return Err(format!(
            "uniform struct is {span} bytes, layout size {}",
            layout.size
        ));
    }
    Ok(())
}
