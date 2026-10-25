// Renders the agent-facing documents of the npm package from the catalog (gl-transitions.json):
//   llms.txt       index in the llmstxt.org format: summary, docs, one line per transition
//   llms-full.txt  every transition with its description, tags, parameters and source links
//   catalog.md     compact index for the Agent Skill (skills/gl-transitions/references/)
// Links point to the published version on jsDelivr, so a document always matches its sources.

const REPO = "https://github.com/gl-transitions/gl-transitions";
const SITE = "https://gl-transitions.com";

// The packages built from this one, linked at the release's tag (gl-transitions@<version>).
const PACKAGES = [
  {
    dir: "packages/react-native-skia",
    title: "React Native Skia",
    description: "`@gl-transitions/react-native-skia`, a `<Transition>` component drawing the SkSL versions",
  },
  {
    dir: "packages/remotion",
    title: "Remotion",
    description:
      "`@gl-transitions/remotion`, `glTransition()` presentations for `<TransitionSeries>`, drawing the GLSL with WebGL 2",
  },
  {
    dir: "crates/gl-transitions",
    title: "Rust",
    description: "the `gl-transitions` crate, every source with typed parameters and packed uniforms",
  },
  {
    dir: "swift",
    title: "Swift",
    description: "the `GLTransitions` package (Metal renderer, AVFoundation compositor), from gl-transitions-swift",
  },
  {
    dir: "android",
    title: "Android",
    description: "`com.gl-transitions:gl-transitions` on Maven Central, AGSL shaders (drawing needs Android 13+)",
  },
];

function packageLinks(version) {
  return PACKAGES.map((p) => `- [${p.title}](${REPO}/tree/gl-transitions@${version}/${p.dir}): ${p.description}`);
}

function cdn(version) {
  return `https://cdn.jsdelivr.net/npm/gl-transitions@${version}`;
}

// A parameter value as a GLSL literal: 0.5, true, vec2(0.5, 0.5).
function glslLiteral(type, value) {
  if (Array.isArray(value)) return `${type}(${value.join(", ")})`;
  return String(value);
}

function formatParam(name, p) {
  let s = `\`${name}\` (${p.type}`;
  if (p.default !== undefined) s += ` = ${glslLiteral(p.type, p.default)}`;
  s += ")";
  const hints = [];
  if (p.min !== undefined && p.max !== undefined)
    hints.push(`range ${p.min} to ${p.max}${p.step ? ` step ${p.step}` : ""}`);
  if (p.color) hints.push("color");
  if (hints.length) s += ` [${hints.join(", ")}]`;
  if (p.description) s += `: ${p.description}`;
  return s;
}

function summary(transitions, version) {
  return `> The open collection of GL Transitions: ${transitions.length} GLSL shaders that turn one image into another as \`progress\` goes from 0 to 1. The npm package also ships SkSL (Skia), GLSL ES 3.00, WGSL (WebGPU) and Metal versions of those that translate. Packages built from it: React Native Skia (SkSL), Remotion (GLSL with WebGL 2), Rust (every source), Swift (Metal) and Android (AGSL). This document describes gl-transitions@${version} (npm).`;
}

const SPEC = `Every transition is GLSL (WebGL 1 / GLSL ES 1.00) that implements \`vec4 transition(vec2 uv)\`. The host provides:

- \`float progress\`: 0.0 shows only the outgoing image, 1.0 only the incoming one
- \`float ratio\`: output width / height
- \`vec4 getFromColor(vec2 uv)\` and \`vec4 getToColor(vec2 uv)\`: sample the outgoing and incoming images (uv in [0, 1], origin at the bottom left)
- one uniform per parameter, set to its default unless the user picks another value
- one \`sampler2D\` per extra texture, for the few transitions that list \`textures\``;

function renderLlmsTxt(transitions, { version }) {
  const base = cdn(version);
  const lines = [
    "# gl-transitions",
    "",
    summary(transitions, version),
    "",
    SPEC,
    "",
    "## Docs",
    "",
    `- [Full catalog](${base}/llms-full.txt): every transition with its description, tags, parameters and source links`,
    `- [Agent Skill](${base}/skills/gl-transitions/SKILL.md): how to pick a transition and wire it into WebGL, WebGPU, Skia, Remotion, editly, FFmpeg, Rust, Swift or Android`,
    `- [Catalog JSON](${base}/gl-transitions.json): the same data as an array of objects (name, glsl, params, tags, ...), typed in index.d.ts`,
    `- [Package README](${base}/README.md): files of the npm package and the contracts of its SkSL, GLSL ES 3.00, WGSL and Metal versions`,
    `- [Compatibility](${base}/compatibility.json): which transitions each target supports, and how close each one renders to the GLSL`,
    ...packageLinks(version),
    `- [Specification](${REPO}#gl-transition-specification-v1): GL Transition Specification v1`,
    "",
    "## Transitions",
    "",
    ...transitions.map(
      (t) =>
        `- [${t.name}](${base}/transitions/${t.name}.glsl)${t.description ? `: ${t.description}` : ""}${t.tags.length ? ` (${t.tags.join(", ")})` : ""}`,
    ),
    "",
    "## Optional",
    "",
    `- [Gallery](${SITE}/gallery): animated previews of every transition`,
    `- [Editor](${SITE}/editor): write and test a transition in the browser`,
    `- [Contributing](${REPO}/blob/master/CONTRIBUTING.md): how to add a transition`,
    "",
  ];
  return lines.join("\n");
}

function renderLlmsFullTxt(transitions, { version, sksl = new Set() }) {
  const base = cdn(version);
  const out = [
    "# gl-transitions",
    "",
    summary(transitions, version),
    "",
    SPEC,
    "",
    `SkSL versions (\`sksl/<name>.sksl\`) are standalone Skia runtime effects: children \`_from\`, \`_to\` (then one per extra texture), uniforms \`float2 _resolution\` (output size in pixels), \`progress\`, \`ratio\` and each parameter by name (\`bool\` parameters are \`int\` 0 or 1), entry point \`half4 main(float2 coord)\` with a top-left origin. Draw both images at the output size.`,
    "",
    `The same transitions as GLSL ES 3.00, WGSL and Metal are at \`glsl3/<name>.glsl\`, \`wgsl/<name>.wgsl\` and \`msl/<name>.metal\` (contracts in the package README, uniform layouts in \`layouts.json\`); \`compatibility.json\` lists the transitions each target supports.`,
    "",
    `Install: \`npm install gl-transitions\` (\`import transitions from "gl-transitions"\`), or fetch the files below. Latest version: ${cdn(version.split(".")[0])}/`,
    "",
    "Packages built from it:",
    "",
    ...packageLinks(version),
    "",
  ];
  for (const t of transitions) {
    out.push(`## ${t.name}`, "");
    if (t.description) out.push(t.description, "");
    if (t.tags.length) out.push(`- Tags: ${t.tags.join(", ")}`);
    const params = Object.entries(t.params);
    if (params.length) {
      out.push("- Parameters:");
      for (const [name, p] of params) out.push(`  - ${formatParam(name, p)}`);
    } else {
      out.push("- Parameters: none");
    }
    if (t.textures.length) out.push(`- Extra textures: ${t.textures.map((x) => `\`${x}\``).join(", ")} (sampler2D)`);
    out.push(`- Author: ${t.author}`, `- License: ${t.license}`);
    out.push(`- GLSL: ${base}/transitions/${t.name}.glsl`);
    if (sksl.has(t.name)) out.push(`- SkSL: ${base}/sksl/${t.name}.sksl`);
    out.push(`- Preview: ${SITE}/editor/${t.name}`, "");
  }
  return out.join("\n");
}

function renderCatalogReference(transitions, { version }) {
  const byTag = new Map();
  for (const t of transitions) for (const tag of t.tags) byTag.set(tag, [...(byTag.get(tag) || []), t.name]);
  const tags = [...byTag].sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0]));
  const out = [
    `# Catalog (gl-transitions@${version})`,
    "",
    `${transitions.length} transitions. Generated from gl-transitions.json; full details (parameter hints, authors, source links) in ${cdn(version)}/llms-full.txt.`,
    "",
    "## By tag",
    "",
    ...tags.map(([tag, names]) => `- **${tag}**: ${names.join(", ")}`),
    "",
    "## Transitions",
    "",
    "`name`: description. Parameters as name (type = default). Extra textures are flagged: the host must provide them.",
    "",
  ];
  for (const t of transitions) {
    let line = `- \`${t.name}\`${t.description ? `: ${t.description}` : ""}`;
    const params = Object.entries(t.params).map(
      ([n, p]) => `${n} (${p.type}${p.default !== undefined ? ` = ${glslLiteral(p.type, p.default)}` : ""})`,
    );
    if (params.length) line += `. Params: ${params.join(", ")}`;
    if (t.textures.length) line += `. Extra textures: ${t.textures.join(", ")}`;
    out.push(line);
  }
  out.push("");
  return out.join("\n");
}

export { renderLlmsTxt, renderLlmsFullTxt, renderCatalogReference, glslLiteral, PACKAGES };
