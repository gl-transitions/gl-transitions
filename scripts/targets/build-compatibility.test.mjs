// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const script = path.join(import.meta.dirname, "build-compatibility.mjs");

test("compatibility: merges target reports, including the combined WGSL/MSL report", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "compat-"));
  const write = (name, data) => {
    fs.writeFileSync(path.join(dir, name), JSON.stringify(data));
    return path.join(dir, name);
  };
  const sksl = write("sksl.json", {
    target: "sksl",
    transitions: [
      { name: "fade", status: "match", differingPixels: 0 },
      { name: "noise", status: "differs", differingPixels: 0.4, hashNoise: true },
    ],
  });
  const gpu = write("gpu.json", {
    wgsl: { target: "wgsl", transitions: [{ name: "fade", status: "compile-error", error: "a\nb" }] },
    msl: { target: "msl", transitions: [{ name: "fade", status: "translated" }] },
  });
  const out = path.join(dir, "compatibility.json");
  const summary = path.join(dir, "summary.md");
  execFileSync("node", [script, "--out", out, "--summary", summary, sksl, gpu]);

  const matrix = JSON.parse(fs.readFileSync(out, "utf8"));
  assert.equal(matrix.targets.sksl.rendered, true);
  assert.equal(matrix.targets.wgsl.rendered, false);
  assert.deepEqual(matrix.transitions.fade, {
    sksl: { status: "match", differingPixels: 0 },
    wgsl: { status: "compile-error", error: "a" },
    msl: { status: "translated" },
  });
  assert.deepEqual(Object.keys(matrix.transitions), ["fade", "noise"]);

  const md = fs.readFileSync(summary, "utf8");
  assert.match(md, /\| match \| 1 \|/);
  assert.match(md, /`fade` \| match \| compile-error \(a\) \| translated/);
  assert.match(md, /`noise` \| differs \(40\.0%, hash noise\)/);
  fs.rmSync(dir, { recursive: true });
});

test("compatibility: lists close renders, escapes compiler messages, a missing reference still counts as rendered", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "compat-"));
  const report = path.join(dir, "wgsl.json");
  fs.writeFileSync(
    report,
    JSON.stringify({
      target: "wgsl",
      transitions: [
        { name: "near", status: "close", differingPixels: 0.04 },
        { name: "new", status: "no-reference", error: "missing new.png" },
        { name: "bad", status: "compile-error", error: "expected <ident>, found `|`" },
      ],
    }),
  );
  const out = path.join(dir, "compatibility.json");
  const md = execFileSync("node", [script, "--out", out, report], { encoding: "utf8" });
  assert.equal(JSON.parse(fs.readFileSync(out, "utf8")).targets.wgsl.rendered, true);
  assert.match(md, /`near` \| close \(4\.0%\)/);
  assert.match(md, /expected &lt;ident&gt;, found \\`\\\|\\`/);
  fs.rmSync(dir, { recursive: true });
});
