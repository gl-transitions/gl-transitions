#!/usr/bin/env node
// Converts every transition to Vulkan GLSL with the binding layout of spirv.mjs,
// compiles it to SPIR-V with glslang and translates it with naga into WGSL and MSL.
// WGSL is validated by naga and, when rendering, by Dawn (Chrome's WebGPU) which
// renders it with the reference images to compare with the GLSL reference renders.
// MSL is compiled with Apple's Metal compiler when it is available (macOS).
//
// Usage:
//   npm run build:wgsl-msl -- --wgsl <dir> --msl <dir> [--layouts <file.json>]
//                             [--refs <glsl renders dir>] [--renders <dir>] [--report <file.json>]
//
//   --wgsl, --msl  write <name>.wgsl / <name>.metal for every transition that translates
//   --layouts      writes the uniform buffer layout and textures of every transition as JSON
//   --refs         PNG strips from scripts/rendering/render-references.mjs to compare against
//                  (needs the optional `webgpu` package)
//   --renders      writes the WGSL renders as PNG strips, for inspection
//   --report       writes the per-transition status of both targets as JSON
//
// Only fails on unexpected crashes: per-transition compatibility is tracked in the report.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } from "../rendering/reference-images.mjs";
import { toVulkanGLSL, tidyNames, bindMetalResources } from "./spirv.mjs";
import { glslangValidator, naga } from "./toolchain.mjs";
import { usesHashNoise, checkRender, writeReport } from "./compare-renders.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");

const args = process.argv.slice(2);
const opt = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) opt[args[i].slice(2)] = path.resolve(args[++i]);
}
if (!opt.wgsl || !opt.msl) {
  console.error(
    "Usage: npm run build:wgsl-msl -- --wgsl <dir> --msl <dir> [--layouts <file>] [--refs <dir>] [--renders <dir>] [--report <file>]",
  );
  process.exit(1);
}

const tools = { glslang: await glslangValidator(), naga: naga() };
const metal = process.platform === "darwin" && spawnSync("xcrun", ["-f", "metal"], { stdio: "ignore" }).status === 0;
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "wgsl-msl-"));

// Runs a tool and returns its error output, or "" on success.
function run(tool, toolArgs) {
  const { status, stdout, stderr, error } = spawnSync(tool, toolArgs, { encoding: "utf8" });
  if (error) throw error;
  if (status === 0) return "";
  return (
    (stdout + stderr)
      .split("\n")
      .map((l) => l.replaceAll(`${tmp}/`, "").trim())
      .filter((l) => l && !/compilation errors|^[\w-]+\.frag$/.test(l))
      .join("\n") || `${path.basename(tool)} exited with ${status}`
  );
}

function header(t, language) {
  return [
    `// ${t.name} — ${language}, generated from https://github.com/gl-transitions/gl-transitions/blob/master/transitions/${t.name}.glsl`,
    `// Author: ${t.author}`,
    `// License: ${t.license}`,
    ...(t.description ? [`// Description: ${t.description}`] : []),
    "// Bindings and uniform layout: see the gl-transitions package README",
    "",
    "",
  ].join("\n");
}

// Translates one transition. Returns { wgsl, msl, layout } or { status, error }.
function translate(transition) {
  let converted;
  try {
    converted = toVulkanGLSL(transition);
  } catch (e) {
    return { status: "unsupported", error: e.message };
  }
  const base = path.join(tmp, transition.name);
  fs.writeFileSync(`${base}.frag`, converted.source);
  const compileError = run(tools.glslang, ["-V", "-o", `${base}.spv`, `${base}.frag`]);
  if (compileError) return { status: "compile-error", error: `glslang: ${compileError}` };
  const translateError = run(tools.naga, [`${base}.spv`, `${base}.raw.wgsl`, `${base}.raw.metal`]);
  if (translateError) return { status: "compile-error", error: `naga: ${translateError}` };

  // Prefer readable function names, unless naga rejects the result.
  const rawWGSL = fs.readFileSync(`${base}.raw.wgsl`, "utf8");
  const tidyWGSL = tidyNames(rawWGSL);
  fs.writeFileSync(`${base}.wgsl`, tidyWGSL);
  const tidy = tidyWGSL === rawWGSL || !run(tools.naga, [`${base}.wgsl`]);
  const rawMSL = fs.readFileSync(`${base}.raw.metal`, "utf8");
  return {
    wgsl: tidy ? tidyWGSL : rawWGSL,
    msl: bindMetalResources(tidy ? tidyNames(rawMSL) : rawMSL, converted.layout),
    layout: converted.layout,
  };
}

// Compiles MSL with Apple's Metal compiler. Returns the errors, or "" on success.
function compileMSL(name, msl) {
  const file = path.join(tmp, `${name}.metal`);
  fs.writeFileSync(file, msl);
  return run("xcrun", ["-sdk", "macosx", "metal", "-c", file, "-o", path.join(tmp, `${name}.air`)]);
}

// --- WGSL rendering with Dawn (optional `webgpu` package) ---

async function createRenderer() {
  let webgpu;
  try {
    webgpu = await import("webgpu");
  } catch {
    throw new Error("--refs and --renders need the optional `webgpu` package (npm install)");
  }
  Object.assign(globalThis, webgpu.globals);
  // Dawn crashes if the GPU object is garbage collected while the device lives: keep it referenced.
  const gpu = webgpu.create([]);
  const adapter = await gpu.requestAdapter();
  if (!adapter) throw new Error("No WebGPU adapter (on Linux, install a Vulkan driver such as Mesa lavapipe)");
  const device = await adapter.requestDevice();

  function texture(rgba) {
    const t = device.createTexture({
      size: [WIDTH, HEIGHT],
      format: "rgba8unorm",
      usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
    });
    device.queue.writeTexture({ texture: t }, rgba, { bytesPerRow: WIDTH * 4 }, [WIDTH, HEIGHT]);
    return t.createView();
  }
  const inputs = { from: texture(fromImage), to: texture(toImage), extra: texture(extraImage) };
  const sampler = device.createSampler({ magFilter: "linear", minFilter: "linear" });
  const target = device.createTexture({
    size: [WIDTH, HEIGHT],
    format: "rgba8unorm",
    usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC,
  });
  const bytesPerRow = Math.ceil((WIDTH * 4) / 256) * 256;
  const readback = device.createBuffer({
    size: bytesPerRow * HEIGHT,
    usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
  });
  // Fullscreen triangle; uv has a bottom-left origin like the GLSL spec.
  const vertex = device.createShaderModule({
    code: `struct Out { @builtin(position) position: vec4f, @location(0) uv: vec2f }
@vertex fn main(@builtin(vertex_index) i: u32) -> Out {
  let p = array(vec2f(-1.0, -1.0), vec2f(3.0, -1.0), vec2f(-1.0, 3.0))[i];
  return Out(vec4f(p, 0.0, 1.0), 0.5 * (p + 1.0));
}`,
  });

  function uniformData(transition, layout, progress) {
    const data = new ArrayBuffer(Math.max(layout.size, 16));
    const f32 = new Float32Array(data);
    const i32 = new Int32Array(data);
    const values = { progress, ratio: WIDTH / HEIGHT, ...transition.defaultParams };
    for (const { name, type, offset } of layout.uniforms) {
      const view = /^(int|bool|ivec\d)$/.test(type) ? i32 : f32;
      [].concat(values[name] ?? 0).forEach((v, k) => (view[offset / 4 + k] = Number(v)));
    }
    return data;
  }

  // Returns the RGBA strip (row 0 = top), or throws with Dawn's validation errors.
  async function render(transition, { wgsl, layout }) {
    device.pushErrorScope("validation");
    const fragment = device.createShaderModule({ code: wgsl });
    const messages = (await fragment.getCompilationInfo()).messages.filter((m) => m.type === "error");
    const textureEntries = ["from", "to", ...layout.textures].map((_, k) => ({
      binding: 2 + k,
      visibility: GPUShaderStage.FRAGMENT,
      texture: {},
    }));
    const bindGroupLayout = device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: {} },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: {} },
        ...textureEntries,
      ],
    });
    const pipeline = device.createRenderPipeline({
      layout: device.createPipelineLayout({ bindGroupLayouts: [bindGroupLayout] }),
      vertex: { module: vertex, entryPoint: "main" },
      fragment: { module: fragment, entryPoint: "main", targets: [{ format: "rgba8unorm" }] },
    });
    const uniforms = device.createBuffer({
      size: Math.max(layout.size, 16),
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    const bindGroup = device.createBindGroup({
      layout: bindGroupLayout,
      entries: [
        { binding: 0, resource: { buffer: uniforms } },
        { binding: 1, resource: sampler },
        { binding: 2, resource: inputs.from },
        { binding: 3, resource: inputs.to },
        ...layout.textures.map((_, k) => ({ binding: 4 + k, resource: inputs.extra })),
      ],
    });
    const error = await device.popErrorScope();
    if (messages.length || error) {
      throw new Error(
        (messages.map((m) => `${m.lineNum}:${m.linePos}: ${m.message}`).join("\n") || error.message).trim(),
      );
    }

    const strip = Buffer.alloc(WIDTH * PROGRESS.length * HEIGHT * 4);
    for (const [f, progress] of PROGRESS.entries()) {
      device.queue.writeBuffer(uniforms, 0, uniformData(transition, layout, progress));
      const encoder = device.createCommandEncoder();
      const pass = encoder.beginRenderPass({
        colorAttachments: [{ view: target.createView(), loadOp: "clear", storeOp: "store", clearValue: [0, 0, 0, 0] }],
      });
      pass.setPipeline(pipeline);
      pass.setBindGroup(0, bindGroup);
      pass.draw(3);
      pass.end();
      encoder.copyTextureToBuffer({ texture: target }, { buffer: readback, bytesPerRow }, [WIDTH, HEIGHT]);
      device.queue.submit([encoder.finish()]);
      await readback.mapAsync(GPUMapMode.READ);
      const pixels = new Uint8Array(readback.getMappedRange());
      for (let y = 0; y < HEIGHT; y++) {
        strip.set(
          pixels.subarray(y * bytesPerRow, y * bytesPerRow + WIDTH * 4),
          (y * WIDTH * PROGRESS.length + f * WIDTH) * 4,
        );
      }
      readback.unmap();
    }
    uniforms.destroy();
    return strip;
  }
  return { gpu, render, destroy: () => device.destroy() };
}

// --- main ---

const dir = path.join(ROOT, "transitions");
const files = fs
  .readdirSync(dir)
  .filter((f) => f.endsWith(".glsl") && fs.statSync(path.join(dir, f)).isFile())
  .sort();
for (const d of [opt.wgsl, opt.msl, opt.renders]) if (d) fs.mkdirSync(d, { recursive: true });
const renderer = opt.refs || opt.renders ? await createRenderer() : null;

const wgslResults = [];
const mslResults = [];
const layouts = {};
for (const file of files) {
  const { transition } = parseTransition(fs.readFileSync(path.join(dir, file), "utf8"), file);
  const wgslResult = { name: transition.name };
  const mslResult = { name: transition.name };
  if (usesHashNoise(transition.glsl)) wgslResult.hashNoise = true;
  wgslResults.push(wgslResult);
  mslResults.push(mslResult);

  const out = translate(transition);
  if (out.status) {
    Object.assign(wgslResult, out);
    Object.assign(mslResult, out);
    continue;
  }
  layouts[transition.name] = out.layout;

  wgslResult.status = "compiled";
  if (renderer) {
    try {
      const strip = await renderer.render(transition, out);
      Object.assign(
        wgslResult,
        checkRender(strip, {
          name: transition.name,
          hashNoise: wgslResult.hashNoise,
          refsDir: opt.refs,
          rendersDir: opt.renders,
        }),
      );
    } catch (e) {
      Object.assign(wgslResult, { status: "compile-error", error: `Dawn: ${e.message}` });
    }
  }
  if (wgslResult.status !== "compile-error") {
    fs.writeFileSync(path.join(opt.wgsl, `${transition.name}.wgsl`), header(transition, "WGSL") + out.wgsl);
  }

  const mslError = metal ? compileMSL(transition.name, out.msl) : "";
  if (mslError) {
    Object.assign(mslResult, { status: "compile-error", error: `metal: ${mslError}` });
  } else {
    mslResult.status = metal ? "compiled" : "translated";
    fs.writeFileSync(path.join(opt.msl, `${transition.name}.metal`), header(transition, "MSL") + out.msl);
  }
}
renderer?.destroy();
fs.rmSync(tmp, { recursive: true, force: true });

if (opt.layouts) fs.writeFileSync(opt.layouts, JSON.stringify(layouts, null, 2) + "\n");
const wgsl = writeReport("wgsl", "WGSL", wgslResults, null);
const msl = writeReport("msl", metal ? "MSL" : "MSL (not compiled: no Metal compiler here)", mslResults, null, [
  "compiled",
  "translated",
]);
if (opt.report) fs.writeFileSync(opt.report, JSON.stringify({ wgsl, msl }, null, 2) + "\n");
process.exit(0);
