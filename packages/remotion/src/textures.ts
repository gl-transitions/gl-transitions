import { cancelRender, continueRender, delayRender } from "remotion";

// The extra textures of some transitions (`luma`, `displacement`…), loaded once per URL.
// Rendering waits for them (delayRender), so every frame is drawn with them.
// HTMLImageElement rather than ImageBitmap: WebGL flips it on upload (UNPACK_FLIP_Y_WEBGL).

const images = new Map<string, HTMLImageElement>();

/** The image of `url` once loaded, or null: the first call starts loading it. */
export function loadImage(url: string): HTMLImageElement | null {
  let image = images.get(url);
  if (!image) {
    image = new Image();
    images.set(url, image);
    const handle = delayRender(`gl-transitions: loading the texture ${url}`);
    image.crossOrigin = "anonymous";
    image.src = url;
    image
      .decode()
      .then(() => continueRender(handle))
      .catch(() => cancelRender(new Error(`gl-transitions: could not load the texture ${url}`)));
  }
  return image.complete && image.naturalWidth > 0 ? image : null;
}
