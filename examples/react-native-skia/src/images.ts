import { AlphaType, ColorType, Skia, type SkImage } from "@shopify/react-native-skia";

// The images of the spec validation (scripts/checks/validate-transition.mjs): from is
// (u, v, 0), to is (u, v, 1), so any mix-up between them, or with the output, shows.
export const SIZE = 64;

function gradient(blue: number): SkImage {
  const pixels = new Uint8Array(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const i = (y * SIZE + x) * 4;
      pixels[i] = Math.round((x / (SIZE - 1)) * 255);
      pixels[i + 1] = Math.round((1 - y / (SIZE - 1)) * 255); // v goes up, like uv
      pixels[i + 2] = blue;
      pixels[i + 3] = 255;
    }
  }
  const info = { width: SIZE, height: SIZE, colorType: ColorType.RGBA_8888, alphaType: AlphaType.Premul };
  const image = Skia.Image.MakeImage(info, Skia.Data.fromBytes(pixels), SIZE * 4);
  if (!image) throw new Error("could not create a test image");
  return image;
}

export const fromImage = gradient(0);
export const toImage = gradient(255);

/** Extra textures (e.g. `luma` for "LumaWipe"), by name: the same gradient works for all. */
export function texturesFor(names: readonly string[]): { [name: string]: SkImage } {
  return Object.fromEntries(names.map((name) => [name, fromImage]));
}
