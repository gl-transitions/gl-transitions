// Renders the Rust catalog of the gl-transitions crate (crates/gl-transitions/generated/catalog.rs)
// from the built npm package: one `Transition` literal per entry of gl-transitions.json, its
// uniform layout from layouts.json and include_str! of the shader files copied next to it.

// The shader targets the crate embeds and their file extension. Each name is the folder in the
// npm package, the `Transition` field and the cargo feature that compiles the sources in (the
// original GLSL is always included).
const TARGETS = [
  { name: "sksl", ext: ".sksl" },
  { name: "glsl3", ext: ".glsl" },
  { name: "wgsl", ext: ".wgsl" },
  { name: "msl", ext: ".metal" },
];

// GLSL parameter types → [Rust `ParamType` and `Value` variant, component count, integer].
const TYPES = {
  float: ["Float", 1, false],
  vec2: ["Vec2", 2, false],
  vec3: ["Vec3", 3, false],
  vec4: ["Vec4", 4, false],
  int: ["Int", 1, true],
  ivec2: ["IVec2", 2, true],
  ivec3: ["IVec3", 3, true],
  ivec4: ["IVec4", 4, true],
  bool: ["Bool", 1, false],
};

// A Rust string literal. Rust has no \uXXXX escape, so only the escapes it shares with JSON
// are used and every other character is written as is (the file is UTF-8).
function str(s) {
  return `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t")}"`;
}

function float(n) {
  if (typeof n !== "number" || !Number.isFinite(n)) throw new Error(`not a finite number: ${n}`);
  // `3` would be an integer literal: floats always get a fraction or an exponent.
  const s = String(n);
  return /[.e]/.test(s) ? s : `${s}.0`;
}

// Every integer of the catalog is an i32 (int parameters) or a small usize (offsets): out of the
// i32 range, the literal would not compile.
function int(n) {
  if (!Number.isInteger(n)) throw new Error(`not an integer: ${n}`);
  if (n < -(2 ** 31) || n >= 2 ** 31) throw new Error(`out of the i32 range: ${n}`);
  return String(n);
}

const option = (value, render) => (value === undefined || value === null ? "None" : `Some(${render(value)})`);

function value(type, def, where) {
  const spec = TYPES[type];
  if (!spec) throw new Error(`${where}: unsupported parameter type ${type}`);
  const [variant, count, integer] = spec;
  if (type === "bool") {
    if (typeof def !== "boolean")
      throw new Error(`${where}: bool default must be a boolean, got ${JSON.stringify(def)}`);
    return `Value::Bool(${def})`;
  }
  const scalar = integer ? int : float;
  if (count === 1) {
    if (typeof def !== "number")
      throw new Error(`${where}: ${type} default must be a number, got ${JSON.stringify(def)}`);
    return `Value::${variant}(${scalar(def)})`;
  }
  if (!Array.isArray(def) || def.length !== count) {
    throw new Error(`${where}: ${type} default must have ${count} components, got ${JSON.stringify(def)}`);
  }
  return `Value::${variant}([${def.map(scalar).join(", ")}])`;
}

function param(name, p, where) {
  const type = TYPES[p.type];
  if (!type) throw new Error(`${where}.${name}: unsupported parameter type ${p.type}`);
  return `Param {
                name: ${str(name)},
                ty: ParamType::${type[0]},
                default: ${value(p.type, p.default, `${where}.${name}`)},
                min: ${option(p.min, float)},
                max: ${option(p.max, float)},
                step: ${option(p.step, float)},
                color: ${p.color === true},
                description: ${option(p.description, str)},
            }`;
}

function layout(l, where) {
  if (!l) return "None";
  const uniforms = l.uniforms.map(({ name, type, offset }) => {
    const t = TYPES[type];
    if (!t) throw new Error(`${where}: unsupported uniform type ${type}`);
    return `UniformField { name: ${str(name)}, ty: ParamType::${t[0]}, offset: ${int(offset)} }`;
  });
  return `Some(UniformLayout {
            size: ${int(l.size)},
            fields: &[
                ${uniforms.join(",\n                ")},
            ],
        })`;
}

// `transitions`: gl-transitions.json; `layouts`: layouts.json; `available`: { [target name]: Set of
// transition names whose file exists for that target }; `version`: the npm package version.
// Returns { rust, files }: the catalog source and the shader files to copy, as
// { from: path in the npm package, to: path in generated/ }.
function renderCatalog({ transitions, layouts, available, version }) {
  const files = [];
  // Sorted by name in UTF-8 byte order, as Rust compares &str, so that `get` can binary search.
  const sorted = [...transitions].sort((a, b) => Buffer.compare(Buffer.from(a.name), Buffer.from(b.name)));
  const entries = sorted.map((t) => {
    const where = t.name;
    const glsl = `glsl/${t.name}.glsl`;
    files.push({ from: `transitions/${t.name}.glsl`, to: glsl });
    const sources = TARGETS.map(({ name, ext }) => {
      const file = `${name}/${t.name}${ext}`;
      const has = available[name]?.has(t.name);
      if (has) files.push({ from: file, to: file });
      return `#[cfg(feature = "${name}")]
        ${name}: ${has ? `Some(include_str!(${str(file)}))` : "None"},`;
    });
    const params = Object.entries(t.params ?? {}).map(([name, p]) => param(name, p, where));
    return `    Transition {
        name: ${str(t.name)},
        author: ${str(t.author ?? "")},
        license: ${str(t.license ?? "")},
        description: ${option(t.description, str)},
        tags: &[${(t.tags ?? []).map(str).join(", ")}],
        params: &[${params.length ? `\n            ${params.join(",\n            ")},\n        ` : ""}],
        textures: &[${(t.textures ?? []).map(str).join(", ")}],
        glsl: include_str!(${str(glsl)}),
        ${sources.join("\n        ")}
        uniform_layout: ${layout(layouts[t.name], where)},
    }`;
  });
  const rust = `// @generated by scripts/rust-crate/build-crate.mjs from the gl-transitions npm package ${version}.
// Do not edit: run \`pnpm run build && pnpm run build:crate\` instead.

/// Version of the gl-transitions npm package the sources were built from.
pub const CATALOG_VERSION: &str = ${str(version)};

// Defaults are written as the transitions declare them (e.g. 3.14159265).
#[allow(clippy::approx_constant, clippy::excessive_precision, clippy::unreadable_literal)]
pub(crate) static TRANSITIONS: &[Transition] = &[
${entries.join(",\n")},
];
`;
  return { rust, files, notices: renderNotices(sorted) };
}

// The transitions under another license than the crate's MIT one, with their original source:
// its comments hold the copyright notice and conditions, which the SkSL, WGSL and Metal
// translations lose.
function renderNotices(transitions) {
  const others = transitions.filter((t) => t.license !== "MIT");
  return `# Licenses of the transitions

The crate is MIT licensed (LICENSE), and so are its transitions except the ones below. Each one
keeps its license in every version the crate embeds (GLSL, SkSL, WGSL, Metal, GLSL ES 3.00): here
is its original source, with its copyright notice and license conditions.
${others
  .map(
    (t) => `
## ${t.name}

${t.license}, by ${t.author}.

\`\`\`glsl
${t.glsl.trimEnd()}
\`\`\`
`,
  )
  .join("")}`;
}

export { TARGETS, renderCatalog };
