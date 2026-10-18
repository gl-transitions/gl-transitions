//! Renders the `Check` video with fframes' Skia renderer on the CPU and writes one strip per
//! transition (`<out>/<name>.png`, one frame per progress value), laid out as the GLSL
//! reference renders. scripts/check.mjs runs it and compares the strips with the references.
//!
//! Usage: check <images dir with from.png, to.png, extra.png> <out dir>

use fframes::{Previewer, RenderOptions};
use fframes_skia_renderer::{SkiaCpuCtx, SkiaFrameRenderer};
use gl_transitions_fframes_example::{CHECK_PROGRESS, Check};
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<PathBuf> = std::env::args_os().skip(1).map(PathBuf::from).collect();
    let [images, out] = args.as_slice() else {
        return Err("usage: check <images dir> <out dir>".into());
    };
    let load = |name: &str| image::open(images.join(name));
    let video = Check::new(&load("from.png")?, &load("to.png")?, &load("extra.png")?);
    std::fs::create_dir_all(out)?;

    let options = RenderOptions::default();
    let mut previewer = Previewer::new(&video, &options)?;
    let cpu = SkiaCpuCtx::new(Check::WIDTH, Check::HEIGHT);
    let mut renderer = SkiaFrameRenderer::new(&cpu);
    let (w, h) = (Check::WIDTH as u32, Check::HEIGHT as u32);
    for (k, transition) in video.transitions().iter().enumerate() {
        let mut strip = image::RgbaImage::new(w * CHECK_PROGRESS.len() as u32, h);
        for i in 0..CHECK_PROGRESS.len() {
            let frame = previewer
                .render(Check::frame_of(k, i), &mut renderer)?
                .into_image();
            image::imageops::replace(&mut strip, &frame, i64::from(w) * i as i64, 0);
        }
        strip.save(out.join(format!("{}.png", transition.transition().name())))?;
    }
    eprintln!(
        "Wrote {} strips to {}",
        video.transitions().len(),
        out.display()
    );
    Ok(())
}
