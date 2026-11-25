// The browser side of benchmark-transitions.mjs: times each transition and posts each result.

import { createFrameTimer, rendererName } from "./frame-timer.mjs";

const post = (url, data) => fetch(url, { method: "POST", body: JSON.stringify(data) });

async function run() {
  const { width, height, progress, timeout, reference, transitions } = await (await fetch("job.json")).json();
  const gl = document
    .createElement("canvas")
    .getContext("webgl", { powerPreference: "high-performance", antialias: false });
  if (!gl) throw new Error("no WebGL");
  await post("renderer", rendererName(gl));

  const images = await Promise.all(
    [1, 2, 3].map(async (n) => {
      const image = new Image();
      image.src = `${n}.jpg`;
      await image.decode();
      const context = new OffscreenCanvas(width, height).getContext("2d");
      context.drawImage(image, 0, 0, width, height);
      // WebGL 1 takes the bytes of an image as a Uint8Array only.
      return { width, height, data: new Uint8Array(context.getImageData(0, 0, width, height).data.buffer) };
    }),
  );
  const measureAll = createFrameTimer(gl, { width, height, progress, images });
  await measureAll(reference, transitions, timeout, (result) => post("result", result));
}

run()
  .catch((e) => post("failure", String(e.message || e)))
  .finally(() => post("done", null));
