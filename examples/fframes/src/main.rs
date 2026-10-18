//! The showcase video with fframes' command line: `render`, `frame`, `strip`…
//! (`cargo run --release -- --help`).

use fframes::cli::{self, NoArgs};
use fframes::{EncoderOptions, RenderOptions};
use fframes_skia_renderer::{SkiaPipelineConfig, cli::SkiaRenderers};
use gl_transitions_fframes_example::Showcase;
use std::process::ExitCode;

// The sample images of the gl-transitions previews.
const IMAGES: [&[u8]; 3] = [
    include_bytes!("../../../scripts/rendering/sample-images/1.jpg"),
    include_bytes!("../../../scripts/rendering/sample-images/2.jpg"),
    include_bytes!("../../../scripts/rendering/sample-images/3.jpg"),
];

fn main() -> ExitCode {
    let args = cli::parse::<NoArgs>();
    let images = IMAGES.map(|bytes| image::load_from_memory(bytes).expect("a sample image"));
    let video = Showcase::new(&images);
    // Shaders only run on the Skia backends (GPU by default, `--renderer skia-cpu` without one).
    cli::new(
        &video,
        RenderOptions {
            video_encoder_options: EncoderOptions {
                preferred_encoder: Some("libx264"),
                codec_params: Some(&[("crf", "18"), ("preset", "medium")]),
                ..Default::default()
            },
            ..Default::default()
        },
    )
    .args(args)
    .renderers(SkiaRenderers::gpu(SkiaPipelineConfig::default()))
    .run()
}
