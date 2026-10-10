// Procedural input images for reference renders (RGBA, row 0 = top).
// Shared by the GLSL reference renderer and the other targets' renderers so
// every target sees exactly the same pixels.

const WIDTH = 160;
const HEIGHT = 100;
const PROGRESS = [0.1, 0.3, 0.5, 0.7, 0.9];

function image(fn) {
  const data = new Uint8Array(WIDTH * HEIGHT * 4);
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const [r, g, b] = fn(x / (WIDTH - 1), y / (HEIGHT - 1), x, y);
      const i = (y * WIDTH + x) * 4;
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
      data[i + 3] = 255;
    }
  }
  return data;
}

// "from": cool diagonal gradient, grid lines, red marker in the top-left corner.
const fromImage = image((u, v, x, y) => {
  if (x < 20 && y < 20) return [230, 40, 40];
  if (x % 20 === 0 || y % 20 === 0) return [235, 240, 250];
  const t = (u + v) / 2;
  return [Math.round(20 + 60 * t), Math.round(70 + 40 * t), Math.round(170 + 60 * (1 - t))];
});

// "to": warm gradient with concentric rings, green marker in the top-left corner.
const toImage = image((u, v, x, y) => {
  if (x < 20 && y < 20) return [40, 200, 70];
  const d = Math.hypot((u - 0.5) * (WIDTH / HEIGHT), v - 0.5);
  const ring = Math.floor(d * 12) % 2 === 0;
  return ring ? [240, 170, 60] : [190, 70, 50];
});

// Extra sampler2D inputs (luma, displacementMap, …): smooth grayscale pattern.
const extraImage = image((u, v) => {
  const g = 0.5 + 0.25 * Math.sin(u * 9.0) + 0.25 * Math.cos(v * 7.0 + u * 3.0);
  const c = Math.round(Math.max(0, Math.min(1, g)) * 255);
  return [c, c, c];
});

export { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage };
