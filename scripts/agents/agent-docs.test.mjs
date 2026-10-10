// Run with: npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { renderLlmsTxt, renderLlmsFullTxt, renderCatalogReference, glslLiteral } from "./agent-docs.mjs";
import { parseTransition } from "../catalog/parse-transition.mjs";

const cube = {
  name: "cube",
  author: "gre",
  license: "MIT",
  description: "The images turn like the faces of a cube",
  tags: ["3d", "rotate"],
  params: {
    persp: { type: "float", default: 0.7, min: 0, max: 1, description: "Amount of perspective" },
    reflection: { type: "float", default: 0.4 },
  },
  textures: [],
};
const luma = { name: "luma", author: "gre", license: "MIT", tags: [], params: {}, textures: ["luma"] };

test("glslLiteral", () => {
  assert.equal(glslLiteral("float", 0.5), "0.5");
  assert.equal(glslLiteral("bool", true), "true");
  assert.equal(glslLiteral("vec2", [0.5, 1]), "vec2(0.5, 1)");
});

test("llms.txt: llmstxt.org layout with versioned links", () => {
  const txt = renderLlmsTxt([cube, luma], { version: "1.2.3" });
  assert.match(txt, /^# gl-transitions\n\n> /);
  assert.match(txt, /\n## Docs\n/);
  assert.match(txt, /\n## Optional\n/);
  assert.ok(
    txt.includes("- [cube](https://cdn.jsdelivr.net/npm/gl-transitions@1.2.3/transitions/cube.glsl): The images"),
  );
  assert.ok(txt.includes("(3d, rotate)"));
  assert.ok(txt.includes("- [luma](https://cdn.jsdelivr.net/npm/gl-transitions@1.2.3/transitions/luma.glsl)\n"));
});

test("llms-full.txt: parameters, textures and SkSL links", () => {
  const txt = renderLlmsFullTxt([cube, luma], { version: "1.2.3", sksl: new Set(["cube"]) });
  assert.ok(txt.includes("  - `persp` (float = 0.7) [range 0 to 1]: Amount of perspective"));
  assert.ok(txt.includes("  - `reflection` (float = 0.4)\n"));
  assert.ok(txt.includes("- SkSL: https://cdn.jsdelivr.net/npm/gl-transitions@1.2.3/sksl/cube.sksl"));
  const lumaSection = txt.slice(txt.indexOf("## luma"));
  assert.ok(lumaSection.includes("- Extra textures: `luma` (sampler2D)"));
  assert.ok(lumaSection.includes("- Parameters: none"));
  assert.ok(!lumaSection.includes("- SkSL:"));
});

test("catalog reference: tag index and one line per transition", () => {
  const md = renderCatalogReference([cube, luma], { version: "1.2.3" });
  assert.ok(md.includes("- **3d**: cube"));
  assert.ok(
    md.includes(
      "- `cube`: The images turn like the faces of a cube. Params: persp (float = 0.7), reflection (float = 0.4)",
    ),
  );
  assert.ok(md.includes("- `luma`. Extra textures: luma"));
});

// The skill tells agents to bake parameters into constants for hosts that can't set uniforms
// (ffmpeg-gl-transition): keep that snippet working on every transition of the collection.
test("skill: bakeParams from references/video.md handles every transition", () => {
  const md = fs.readFileSync("skills/gl-transitions/references/video.md", "utf8");
  const block = [...md.matchAll(/```js\n([\s\S]*?)```/g)].map((m) => m[1]).find((b) => b.includes("bakeParams"));
  assert.ok(block, "bakeParams snippet not found");
  const bakeParams = new Function(`${block.replace(/^import .*\n/m, "")}\nreturn bakeParams;`)();
  for (const file of fs.readdirSync("transitions").filter((f) => f.endsWith(".glsl"))) {
    const glsl = fs.readFileSync(path.join("transitions", file), "utf8");
    const { transition } = parseTransition(glsl, file);
    const baked = bakeParams(transition);
    for (const [name, p] of Object.entries(transition.params)) {
      const code = baked.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
      assert.ok(!new RegExp(`uniform[^;]*\\b${name}\\b[^;]*;`).test(code), `${file}: uniform ${name} left`);
      assert.ok(baked.includes(`const ${p.type} ${name} = `), `${file}: const ${name} missing`);
    }
  }
});
