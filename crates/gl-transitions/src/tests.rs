use super::*;

fn f32s(bytes: &[u8]) -> Vec<f32> {
    bytes
        .chunks(4)
        .map(|c| f32::from_ne_bytes(c.try_into().unwrap()))
        .collect()
}

#[test]
fn the_collection_is_complete_and_sorted() {
    let names: Vec<&str> = all().iter().map(Transition::name).collect();
    assert!(names.len() >= 100, "{} transitions", names.len());
    let mut sorted = names.clone();
    sorted.sort();
    sorted.dedup();
    assert_eq!(names, sorted, "sorted by name, without duplicates");
    for t in all() {
        assert_eq!(get(t.name()).map(Transition::name), Some(t.name()));
    }
    assert!(CATALOG_VERSION.split('.').count() == 3, "{CATALOG_VERSION}");
}

#[test]
fn get_finds_transitions_by_exact_name() {
    let fade = get("fade").unwrap();
    assert_eq!(fade.name(), "fade");
    assert!(fade.glsl().contains("vec4 transition"));
    assert!(fade.params().is_empty() && fade.textures().is_empty());
    assert!(get("Fade").is_none());
    assert!(get("nope").is_none());
}

// A target can leave out a transition it fails to convert (compatibility.json): only what is
// shipped is checked, and each target ships something.
#[test]
#[cfg(all(feature = "sksl", feature = "glsl3", feature = "wgsl", feature = "msl"))]
fn every_transition_has_metadata_and_valid_sources() {
    let mut shipped = [0; 4];
    for t in all() {
        assert!(
            !t.author().is_empty() && !t.license().is_empty(),
            "{}",
            t.name()
        );
        assert!(t.glsl().contains("transition"), "{}", t.name());
        let sources = [
            t.sksl().map(|s| s.contains("half4 main(")),
            t.glsl3().map(|s| s.contains("transition")),
            t.wgsl().map(|s| s.contains("@fragment")),
            t.msl().map(|s| s.contains("main_")),
        ];
        for (count, source) in shipped.iter_mut().zip(sources) {
            if let Some(valid) = source {
                assert!(valid, "{}", t.name());
                *count += 1;
            }
        }
        if t.wgsl().is_some() || t.msl().is_some() {
            assert!(t.uniform_layout().is_some(), "{}", t.name());
        }
        for p in t.params() {
            assert_eq!(p.default.ty(), p.ty, "{}.{}", t.name(), p.name);
        }
    }
    assert!(shipped.iter().all(|&n| n > 0), "{shipped:?}");
}

#[test]
fn every_license_is_in_the_crate_license() {
    let crate_license = env!("CARGO_PKG_LICENSE");
    for t in all() {
        let spdx = match t.license() {
            "MIT" => "MIT",
            "BSD 2 Clause" => "BSD-2-Clause",
            "BSD 3 Clause" => "BSD-3-Clause",
            other => panic!("{}: add the license `{other}` to Cargo.toml", t.name()),
        };
        assert!(
            crate_license.contains(spdx),
            "{}: {spdx} not in {crate_license}",
            t.name()
        );
    }
}

#[test]
fn params_are_typed() {
    let t = get("Directional").unwrap();
    let mut params = t.default_params();
    assert_eq!(params.get("direction"), Some(Value::Vec2([0.0, 1.0])));
    params.set("direction", [1.0, 0.0]).unwrap();
    assert_eq!(params.get("direction"), Some(Value::Vec2([1.0, 0.0])));
    assert_eq!(
        params.set("direction", 1.0).unwrap_err(),
        ParamError::WrongType {
            name: "direction",
            expected: ParamType::Vec2,
            found: ParamType::Float
        }
    );
    let err = params.set("nope", 1.0).unwrap_err();
    assert_eq!(
        err.to_string(),
        "transition `Directional` has no parameter `nope`"
    );
    assert_eq!(
        ParamError::WrongType {
            name: "a",
            expected: ParamType::IVec2,
            found: ParamType::Float
        }
        .to_string(),
        "parameter `a` is a ivec2, got a float"
    );
}

#[test]
fn sksl_uniforms_are_packed_in_declaration_order() {
    let t = get("Bounce").unwrap();
    let params = t.default_params().with("bounces", 4.0).unwrap();
    let data = f32s(&params.sksl_uniforms(0.25, 200.0, 100.0));
    // _resolution, progress, ratio, shadow_colour, shadow_height, bounces
    assert_eq!(
        data,
        [200.0, 100.0, 0.25, 2.0, 0.0, 0.0, 0.0, 0.6, 0.075, 4.0]
    );
}

#[test]
fn bools_are_ints_in_the_shaders() {
    let t = get("BowTieWithParameter").unwrap();
    let params = t.default_params().with("reverse", true).unwrap();
    let data = params.sksl_uniforms(0.5, 1.0, 1.0);
    assert_eq!(
        i32::from_ne_bytes(data[data.len() - 4..].try_into().unwrap()),
        1
    );
    assert_eq!(Value::Bool(true).as_shader_value(), Value::Int(1));
    assert_eq!(Value::Float(2.0).as_shader_value(), Value::Float(2.0));
}

#[test]
fn uniform_buffer_follows_the_layout() {
    let t = get("GridFlip").unwrap();
    let layout = t.uniform_layout().unwrap();
    let params = t.default_params().with("size", [3, 5]).unwrap();
    let buffer = params.uniform_buffer(0.5, 2.0).unwrap();
    assert_eq!(buffer.len(), layout.size.max(16));
    let at = |name: &str| {
        layout
            .fields
            .iter()
            .find(|f| f.name == name)
            .unwrap()
            .offset
    };
    let f = |o: usize| f32::from_le_bytes(buffer[o..o + 4].try_into().unwrap());
    let i = |o: usize| i32::from_le_bytes(buffer[o..o + 4].try_into().unwrap());
    assert_eq!((f(at("progress")), f(at("ratio"))), (0.5, 2.0));
    assert_eq!((i(at("size")), i(at("size") + 4)), (3, 5));
    let bgcolor = at("bgcolor");
    assert_eq!(bgcolor % 16, 0, "vec4 is 16-byte aligned");
    assert_eq!(
        [f(bgcolor), f(bgcolor + 4), f(bgcolor + 8), f(bgcolor + 12)],
        [0.0, 0.0, 0.0, 1.0]
    );
}

#[test]
fn uniform_buffers_are_at_least_16_bytes() {
    for t in all() {
        if let Some(buffer) = t.default_params().uniform_buffer(0.0, 1.0) {
            let size = t.uniform_layout().unwrap().size;
            assert_eq!(buffer.len(), size.max(16), "{}", t.name());
        }
    }
}
