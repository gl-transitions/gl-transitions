import { useLayoutEffect, useRef } from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";

const VERTEX = "attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }";

// The background: a domain-warped noise field (flowing smoke / marble) with subtle dark contour
// lines, film grain and a vignette. GLSL ES 1.00.
const BACKDROP = `precision highp float;
uniform vec2 resolution;
uniform float time;
uniform float seed;
uniform vec3 base;   // darkest color
uniform vec3 mid;    // body of the flow
uniform vec3 accent; // highlights

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 r = mat2(0.8, 0.6, -0.6, 0.8);
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = r * p * 2.03 + 11.7;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = gl_FragCoord.xy;
  vec2 uv = frag / resolution;
  vec2 p = (frag - 0.5 * resolution) / resolution.y * 0.9 + seed;
  float t = time * 0.025;

  // Domain warping: the field is sampled where another field points.
  vec2 q = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, 1.3) - t));
  vec2 r = vec2(fbm(p + 2.2 * q + vec2(1.7, 9.2) + t), fbm(p + 2.2 * q + vec2(8.3, 2.8) - t));
  float f = fbm(p + 2.0 * r);

  // Mostly the dark base; the body color where the flow is dense.
  vec3 c = mix(base, mid, smoothstep(0.25, 0.8, f));
  c += mid * 0.35 * smoothstep(0.5, 1.0, r.y);

  // A soft glow of the accent where the flow is dense.
  c += accent * 0.16 * smoothstep(0.55, 0.9, f);

  // Thin contour lines of the field, slightly darker than what they cross.
  float d = abs(fract(f * 9.0 + 0.5) - 0.5);
  float line = 1.0 - smoothstep(0.0, 0.045, d);
  c *= 1.0 - 0.3 * line * smoothstep(0.3, 0.6, f);

  // Vignette and animated film grain.
  vec2 v = uv - 0.5;
  c *= 1.0 - 0.9 * dot(v, v);
  c += (hash(frag + fract(time * 7.13) * 91.7) - 0.5) * 0.035;
  gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
`;

export type Palette = {
  base: [number, number, number];
  mid: [number, number, number];
  accent: [number, number, number];
};

type Renderer = {
  canvas: OffscreenCanvas;
  gl: WebGLRenderingContext;
  uniform: (name: string) => WebGLUniformLocation | null;
};

// One WebGL context for every backdrop, drawing off screen; each backdrop copies the result into
// its own 2D canvas. Remotion remounts a scene when a transition starts (it captures the scene,
// HTML-in-canvas): a 2D canvas has its pixels right away, where a new WebGL canvas would be
// captured blank for a frame, and the shader is not compiled again.
let shared: Renderer | null = null;

function getRenderer(): Renderer {
  if (shared && !shared.gl.isContextLost()) return shared;
  const canvas = new OffscreenCanvas(1, 1);
  const gl = canvas.getContext("webgl")!;
  const program = gl.createProgram()!;
  for (const [type, source] of [
    [gl.VERTEX_SHADER, VERTEX],
    [gl.FRAGMENT_SHADER, BACKDROP],
  ] as const) {
    const shader = gl.createShader(type)!;
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader) ?? "backdrop");
    gl.attachShader(program, shader);
  }
  gl.bindAttribLocation(program, 0, "p");
  gl.linkProgram(program);
  gl.useProgram(program);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  shared = { canvas, gl, uniform: (name) => gl.getUniformLocation(program, name) };
  return shared;
}

const rgb = (c: [number, number, number]) => c.map((v) => v / 255) as [number, number, number];

/** The animated background at the current frame; `seed` picks another region of the field. */
export const Backdrop = ({ palette, seed }: { palette: Palette; seed: number }) => {
  const frame = useCurrentFrame();
  const { fps, width: compositionWidth, height: compositionHeight } = useVideoConfig();
  const canvas = useRef<HTMLCanvasElement>(null);
  useLayoutEffect(() => {
    const element = canvas.current!;
    // In device pixels at its layout size (without the Studio's preview scale): when Remotion
    // captures the scene for a transition, Chrome paints a canvas at its bitmap size, pixel for
    // pixel, whatever its CSS size. Before the first layout, the composition size.
    const width = Math.round((element.offsetWidth || compositionWidth) * devicePixelRatio);
    const height = Math.round((element.offsetHeight || compositionHeight) * devicePixelRatio);
    if (element.width !== width || element.height !== height) {
      element.width = width;
      element.height = height;
    }
    const { canvas: offscreen, gl, uniform } = getRenderer();
    if (offscreen.width !== width || offscreen.height !== height) {
      offscreen.width = width;
      offscreen.height = height;
    }
    gl.viewport(0, 0, width, height);
    gl.uniform2f(uniform("resolution"), width, height);
    gl.uniform1f(uniform("time"), frame / fps);
    gl.uniform1f(uniform("seed"), seed);
    gl.uniform3f(uniform("base"), ...rgb(palette.base));
    gl.uniform3f(uniform("mid"), ...rgb(palette.mid));
    gl.uniform3f(uniform("accent"), ...rgb(palette.accent));
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    element.getContext("2d")!.drawImage(offscreen, 0, 0);
  });
  return <canvas ref={canvas} style={{ position: "absolute", width: "100%", height: "100%" }} />;
};
