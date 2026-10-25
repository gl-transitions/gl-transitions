//! gl-transitions in fframes: the `gl-transitions` crate's SkSL drawn as an fframes shader layer
//! between two images (or two video frames: `get_synced_video_frame(..).into_image()`).

use fframes::media::{ImageData, ImageMetadata};
use fframes::{
    AudioMap, Color, Duration, FFramesContext, Frame, Shader, ShaderUniforms, Svgr, Video,
};
use gl_transitions::{ParamValues, Transition, Value};
use std::sync::Arc;

/// A transition of the collection, compiled once as an fframes [`Shader`].
#[derive(Debug, Clone)]
pub struct GlTransition {
    transition: &'static Transition,
    shader: Shader,
    params: ParamValues,
}

impl GlTransition {
    /// The transition `name` with its default parameters.
    pub fn new(name: &str) -> Self {
        let transition =
            gl_transitions::get(name).unwrap_or_else(|| panic!("no transition `{name}`"));
        let sksl = transition
            .sksl()
            .expect("every transition has an SkSL version");
        Self {
            transition,
            shader: Shader::sksl(sksl),
            params: transition.default_params(),
        }
    }

    /// Changes a parameter (type-checked by the crate).
    pub fn with(mut self, name: &str, value: impl Into<Value>) -> Self {
        self.params
            .set(name, value)
            .unwrap_or_else(|e| panic!("{e}"));
        self
    }

    pub fn transition(&self) -> &'static Transition {
        self.transition
    }

    /// The image to place with `<image href={layer.href()} width={width} height={height} />`.
    ///
    /// The SkSL samples `_from`, `_to` and the extra `textures` at `uv * _resolution`, and fframes
    /// binds images in their own pixels: every image must be `width` x `height`.
    pub fn draw(
        &self,
        frame: &Frame,
        progress: f32,
        from: &ImageData<'_>,
        to: &ImageData<'_>,
        textures: &[&ImageData<'_>],
        (width, height): (f32, f32),
    ) -> ImageData<'static> {
        let mut uniforms = ShaderUniforms::new()
            .float2("_resolution", width, height)
            .float("progress", progress)
            .float("ratio", width / height)
            .image("_from", from)
            .image("_to", to);
        for (name, image) in self.transition.textures().iter().zip(textures) {
            uniforms = uniforms.image(*name, image);
        }
        for (param, value) in self.params.iter() {
            // SkSL declares bool parameters as int.
            uniforms = match value.as_shader_value() {
                Value::Float(v) => uniforms.float(param.name, v),
                Value::Vec2([x, y]) => uniforms.float2(param.name, x, y),
                Value::Vec3([x, y, z]) => uniforms.float3(param.name, x, y, z),
                Value::Vec4([x, y, z, w]) => uniforms.float4(param.name, x, y, z, w),
                Value::Int(v) => uniforms.int(param.name, v),
                // fframes has no int2/int3/int4 uniform values (GridFlip's `size`): the
                // renderer leaves them at zero and logs it.
                _ => uniforms,
            };
        }
        self.shader.draw(frame, uniforms)
    }
}

/// An RGBA image of exactly `width` x `height`: resized to cover it and center-cropped.
pub fn image_of_size(
    name: &str,
    image: &image::DynamicImage,
    width: u32,
    height: u32,
) -> ImageData<'static> {
    let rgba = image
        .resize_to_fill(width, height, image::imageops::FilterType::Lanczos3)
        .to_rgba8();
    let data =
        fframes::usvgr::PreloadedImageData::new(name.to_owned(), width, height, rgba.as_raw());
    ImageData::new_from_raw_data(
        Arc::new(data),
        name.to_owned(),
        ImageMetadata { width, height },
    )
}

/// A grayscale spiral, for transitions with an extra texture (`LumaWipe`, `DisplacementMap`).
pub fn spiral(width: u32, height: u32) -> image::DynamicImage {
    let (w, h) = (width as f32, height as f32);
    image::DynamicImage::ImageLuma8(image::GrayImage::from_fn(width, height, |x, y| {
        let (dx, dy) = ((x as f32 - w / 2.0) / h, (y as f32 - h / 2.0) / h);
        let v = (dy.atan2(dx) / std::f32::consts::TAU + 0.5 + dx.hypot(dy) * 1.2).fract();
        image::Luma([(v * 255.0) as u8])
    }))
}

/// Seconds an image stays on screen before the next transition, and each transition's duration.
const HOLD: f32 = 0.6;
const TRANSITION: f32 = 1.2;

/// A slideshow: each image in turn, with a different transition between them.
#[derive(Debug)]
pub struct Showcase {
    images: Vec<ImageData<'static>>,
    texture: ImageData<'static>,
    transitions: Vec<GlTransition>,
}

impl Showcase {
    pub const WIDTH: usize = 960;
    pub const HEIGHT: usize = 540;

    pub fn new(images: &[image::DynamicImage]) -> Self {
        let (w, h) = (Self::WIDTH as u32, Self::HEIGHT as u32);
        Self {
            images: images
                .iter()
                .enumerate()
                .map(|(i, image)| image_of_size(&format!("image-{i}"), image, w, h))
                .collect(),
            texture: image_of_size("spiral", &spiral(w, h), w, h),
            transitions: vec![
                GlTransition::new("CrossWarp"),
                GlTransition::new("Cube").with("persp", 0.5),
                GlTransition::new("LumaWipe"),
                GlTransition::new("DirectionalWarp").with("direction", [1.0, 0.0]),
                GlTransition::new("Bounce").with("bounces", 2.0),
                GlTransition::new("Doorway"),
            ],
        }
    }
}

impl Video for Showcase {
    const FPS: usize = 30;
    const WIDTH: usize = Showcase::WIDTH;
    const HEIGHT: usize = Showcase::HEIGHT;

    fn duration(&self) -> Duration<'_> {
        Duration::Seconds(self.transitions.len() as f32 * (HOLD + TRANSITION) + HOLD)
    }

    fn audio(&self) -> AudioMap<'_> {
        AudioMap::none()
    }

    fn render_frame<'a>(&'a self, frame: Frame, _ctx: &FFramesContext<'a, '_>) -> Svgr<'a> {
        let (w, h) = (Self::WIDTH as f32, Self::HEIGHT as f32);
        let t = frame.seconds();
        let step = ((t / (HOLD + TRANSITION)) as usize).min(self.transitions.len() - 1);
        let progress =
            ((t - step as f32 * (HOLD + TRANSITION) - HOLD) / TRANSITION).clamp(0.0, 1.0);
        let image = |i: usize| &self.images[i % self.images.len()];
        let layer = if progress <= 0.0 {
            image(step).clone()
        } else if progress >= 1.0 {
            image(step + 1).clone()
        } else {
            self.transitions[step].draw(
                &frame,
                progress,
                image(step),
                image(step + 1),
                &[&self.texture],
                (w, h),
            )
        };
        fframes::svgr!(
            <svg xmlns="http://www.w3.org/2000/svg" width={Self::WIDTH} height={Self::HEIGHT} viewBox={format!("0 0 {w} {h}")}>
                <image href={layer.href()} x="0" y="0" width={w} height={h} />
            </svg>
        )
    }
}

/// Progress values of the GLSL reference renders (scripts/rendering/reference-images.mjs).
pub const CHECK_PROGRESS: [f32; 5] = [0.1, 0.3, 0.5, 0.7, 0.9];

/// Every transition in turn between the images of the GLSL reference renders, one frame per
/// progress value of `CHECK_PROGRESS`, to compare with those renders.
#[derive(Debug)]
pub struct Check {
    from: ImageData<'static>,
    to: ImageData<'static>,
    extra: ImageData<'static>,
    transitions: Vec<GlTransition>,
}

impl Check {
    pub const WIDTH: usize = 160;
    pub const HEIGHT: usize = 100;

    /// `from`, `to` and `extra` are the reference images, already `WIDTH` x `HEIGHT`.
    pub fn new(
        from: &image::DynamicImage,
        to: &image::DynamicImage,
        extra: &image::DynamicImage,
    ) -> Self {
        let (w, h) = (Self::WIDTH as u32, Self::HEIGHT as u32);
        Self {
            from: image_of_size("from", from, w, h),
            to: image_of_size("to", to, w, h),
            extra: image_of_size("extra", extra, w, h),
            transitions: gl_transitions::all()
                .iter()
                .map(|t| GlTransition::new(t.name()))
                .collect(),
        }
    }

    pub fn transitions(&self) -> &[GlTransition] {
        &self.transitions
    }

    /// The frame showing transition `k` at `CHECK_PROGRESS[i]`.
    pub fn frame_of(k: usize, i: usize) -> usize {
        k * CHECK_PROGRESS.len() + i
    }
}

impl Video for Check {
    const FPS: usize = 10;
    const WIDTH: usize = Check::WIDTH;
    const HEIGHT: usize = Check::HEIGHT;
    // The references are transparent where a transition returns alpha < 1.
    const BACKGROUND_COLOR: Color = Color::TRANSPARENT;

    fn duration(&self) -> Duration<'_> {
        Duration::Frames(self.transitions.len() * CHECK_PROGRESS.len())
    }

    fn audio(&self) -> AudioMap<'_> {
        AudioMap::none()
    }

    fn render_frame<'a>(&'a self, frame: Frame, _ctx: &FFramesContext<'a, '_>) -> Svgr<'a> {
        let (w, h) = (Self::WIDTH as f32, Self::HEIGHT as f32);
        let n = CHECK_PROGRESS.len();
        let transition = &self.transitions[frame.index / n];
        let progress = CHECK_PROGRESS[frame.index % n];
        let extra = vec![&self.extra; transition.transition().textures().len()];
        let layer = transition.draw(&frame, progress, &self.from, &self.to, &extra, (w, h));
        fframes::svgr!(
            <svg xmlns="http://www.w3.org/2000/svg" width={Self::WIDTH} height={Self::HEIGHT} viewBox={format!("0 0 {w} {h}")}>
                <image href={layer.href()} x="0" y="0" width={w} height={h} />
            </svg>
        )
    }
}
