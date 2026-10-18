//! Every embedded SkSL shader compiles with Skia (skia-safe, on the CPU), declares the documented
//! children and uniforms, and takes `ParamValues::sksl_uniforms` as its uniform data.
#![cfg(feature = "sksl")]

use skia_safe::runtime_effect::ChildPtr;
use skia_safe::{
    shaders, surfaces, AlphaType, Color, ColorType, Data, ImageInfo, Paint, Rect, RuntimeEffect,
};

#[test]
fn every_sksl_shader_compiles_with_the_documented_interface() {
    // A transition the npm build could not convert has no SkSL (compatibility.json): skipped.
    let shipped: Vec<_> = gl_transitions::all()
        .iter()
        .filter(|t| t.sksl().is_some())
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

fn check(t: &'static gl_transitions::Transition) -> Result<(), String> {
    let effect = RuntimeEffect::make_for_shader(t.sksl().unwrap(), None)?;

    let mut children = vec!["_from", "_to"];
    children.extend(t.textures());
    let actual: Vec<&str> = effect.children().iter().map(|c| c.name()).collect();
    if actual != children {
        return Err(format!("children {actual:?}, expected {children:?}"));
    }

    // Where sksl_uniforms puts each value: packed in declaration order, 4 bytes per component.
    let mut expected = vec![
        ("_resolution".to_owned(), 0, 8),
        ("progress".into(), 8, 4),
        ("ratio".into(), 12, 4),
    ];
    let mut offset = 16;
    for p in t.params() {
        let size = 4 * p.ty.components();
        expected.push((p.name.to_owned(), offset, size));
        offset += size;
    }
    let actual: Vec<(String, usize, usize)> = effect
        .uniforms()
        .iter()
        .map(|u| (u.name().to_owned(), u.offset(), u.size_in_bytes()))
        .collect();
    if actual != expected {
        return Err(format!("uniforms {actual:?}, expected {expected:?}"));
    }
    let data = t.default_params().sksl_uniforms(0.5, 64.0, 32.0);
    if data.len() != effect.uniform_size() {
        return Err(format!(
            "{} bytes of uniforms, Skia expects {}",
            data.len(),
            effect.uniform_size()
        ));
    }
    Ok(())
}

/// Draws `name` (a simple transition every target ships) at `progress` between two plain colors and returns the RGBA pixel at (x, y).
fn render(name: &str, progress: f32, from: Color, to: Color, (x, y): (usize, usize)) -> [u8; 4] {
    let t = gl_transitions::get(name).unwrap();
    let (w, h) = (8, 4);
    let effect = RuntimeEffect::make_for_shader(t.sksl().unwrap(), None).unwrap();
    let data = Data::new_copy(
        &t.default_params()
            .sksl_uniforms(progress, w as f32, h as f32),
    );
    let children = [
        ChildPtr::Shader(shaders::color(from)),
        ChildPtr::Shader(shaders::color(to)),
    ];
    let mut paint = Paint::default();
    paint.set_shader(effect.make_shader(data, &children, None).unwrap());
    let mut surface = surfaces::raster_n32_premul((w, h)).unwrap();
    surface
        .canvas()
        .draw_rect(Rect::from_wh(w as f32, h as f32), &paint);
    let info = ImageInfo::new((w, h), ColorType::RGBA8888, AlphaType::Unpremul, None);
    let mut pixels = vec![0u8; (w * h * 4) as usize];
    assert!(surface.read_pixels(&info, &mut pixels, (w * 4) as usize, (0, 0)));
    let i = (y * w as usize + x) * 4;
    pixels[i..i + 4].try_into().unwrap()
}

#[test]
fn fade_mixes_the_two_images() {
    let [r, g, b, a] = render("fade", 0.5, Color::RED, Color::BLUE, (3, 2));
    assert!(
        r.abs_diff(128) <= 1 && g == 0 && b.abs_diff(128) <= 1 && a == 255,
        "{:?}",
        [r, g, b, a]
    );
}

#[test]
fn wipes_go_the_documented_way() {
    // wipeLeft: the incoming image enters from the right edge (the GLSL reference).
    let (from, to) = (Color::RED, Color::BLUE);
    assert_eq!(render("wipeLeft", 0.25, from, to, (7, 1)), [0, 0, 255, 255]);
    assert_eq!(render("wipeLeft", 0.25, from, to, (0, 1)), [255, 0, 0, 255]);
    // wipeUp: the incoming image enters from the bottom edge, so uv has a bottom-left origin.
    assert_eq!(render("wipeUp", 0.25, from, to, (4, 3)), [0, 0, 255, 255]);
    assert_eq!(render("wipeUp", 0.25, from, to, (4, 0)), [255, 0, 0, 255]);
}
