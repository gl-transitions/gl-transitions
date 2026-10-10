// Pinned native shader tools used by the targets, installed on first use into
// node_modules/.cache/gl-transitions-toolchain (so `npm ci` starts clean).
//
//   glslang  Khronos reference compiler: validates GLSL ES 3.00 and compiles Vulkan GLSL
//            to SPIR-V. Prebuilt release archive, checked against the SHA-256 below
//            before anything is extracted.
//   naga     The wgpu project's shader translator: SPIR-V to WGSL and MSL. No prebuilt
//            release, so `cargo install --locked` builds the pinned version (needs Rust).
//
// Set GLSLANG_VALIDATOR or NAGA to use other binaries.

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";

const ROOT = path.join(import.meta.dirname, "..", "..");
const CACHE = path.join(ROOT, "node_modules", ".cache", "gl-transitions-toolchain");

const GLSLANG = {
  version: "16.6.0",
  archives: {
    "darwin-arm64": ["macos-universal", "4f8c05f2888a73ed0b7b274bc524af9130e09ae94b43c0f3f9ed83cfae852834"],
    "darwin-x64": ["macos-universal", "4f8c05f2888a73ed0b7b274bc524af9130e09ae94b43c0f3f9ed83cfae852834"],
    "linux-x64": ["linux-x86_64", "2c34071f56ecf39d16233294d3739cf43f981fd39080f2fd9dccb782101191ce"],
  },
};

const NAGA_VERSION = "30.0.1";

async function download(url, sha256, file) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  const data = Buffer.from(await res.arrayBuffer());
  const actual = crypto.createHash("sha256").update(data).digest("hex");
  if (actual !== sha256) throw new Error(`${url}: SHA-256 is ${actual}, expected ${sha256}`);
  fs.writeFileSync(file, data);
}

// Returns the path of glslangValidator, downloading it if needed.
async function glslangValidator() {
  if (process.env.GLSLANG_VALIDATOR) return process.env.GLSLANG_VALIDATOR;
  const { version, archives } = GLSLANG;
  const dir = path.join(CACHE, `glslang-${version}`);
  const bin = path.join(dir, "bin", "glslangValidator");
  if (fs.existsSync(bin)) return bin;
  const platform = `${process.platform}-${process.arch}`;
  if (!archives[platform]) {
    throw new Error(
      `No prebuilt glslang ${version} for ${platform}: set GLSLANG_VALIDATOR to a glslangValidator binary`,
    );
  }
  const [asset, sha256] = archives[platform];
  const name = `glslang-${version}-${asset}-release.tar.gz`;
  fs.mkdirSync(dir, { recursive: true });
  const archive = path.join(dir, name);
  await download(`https://github.com/KhronosGroup/glslang/releases/download/${version}/${name}`, sha256, archive);
  execFileSync("tar", ["-xzf", archive, "-C", dir, "bin/glslang", "bin/glslangValidator"]);
  fs.rmSync(archive);
  return bin;
}

// Returns the path of naga, building it with cargo if needed.
function naga() {
  if (process.env.NAGA) return process.env.NAGA;
  const dir = path.join(CACHE, `naga-${NAGA_VERSION}`);
  const bin = path.join(dir, "bin", process.platform === "win32" ? "naga.exe" : "naga");
  if (fs.existsSync(bin)) return bin;
  console.error(`Building naga-cli ${NAGA_VERSION} with cargo (once)…`);
  const { status, error } = spawnSync(
    "cargo",
    ["install", "naga-cli", "--version", NAGA_VERSION, "--locked", "--root", dir],
    { stdio: ["ignore", "inherit", "inherit"] },
  );
  if (error || status !== 0) {
    throw new Error(`Could not build naga-cli ${NAGA_VERSION}: install Rust (https://rustup.rs) or set NAGA`);
  }
  return bin;
}

export { glslangValidator, naga };
