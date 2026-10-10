// Pinned native shader tools used by the targets, installed on first use into
// node_modules/.cache/gl-transitions-toolchain (so `npm ci` starts clean).
//
//   glslang  Khronos reference compiler: validates GLSL ES 3.00. Prebuilt release
//            archive, checked against the SHA-256 below before anything is extracted.
//
// Set GLSLANG_VALIDATOR to use another binary (e.g. on a platform without a prebuilt archive).

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

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

export { glslangValidator };
