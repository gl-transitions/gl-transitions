// Minimal GLSL preprocessor for targets without one (SkSL, WGSL text paths).
// Strips comments, expands object-like and function-like #define macros and
// resolves #ifdef / #ifndef / #else / #endif. GL_ES is not defined: the
// precision blocks some shaders wrap in `#ifdef GL_ES` are dropped.

function stripComments(src) {
  // Keep newlines so line numbers in error messages still match the source.
  return src
    .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, " "))
    .replace(/\/\/.*$/gm, "");
}

const IDENT = /[A-Za-z_]\w*/y;

// Expands macros in `text`. `active` holds macro names being expanded, to stop recursion.
function expand(text, macros, active = new Set()) {
  let out = "";
  let i = 0;
  while (i < text.length) {
    IDENT.lastIndex = i;
    const m = IDENT.exec(text);
    const prev = i > 0 ? text[i - 1] : "";
    if (!m || /[\w.]/.test(prev)) {
      out += text[i++];
      continue;
    }
    const name = m[0];
    i += name.length;
    const macro = macros.get(name);
    if (!macro || active.has(name)) {
      out += name;
      continue;
    }
    if (!macro.params) {
      out += expand(macro.body, macros, new Set([...active, name]));
      continue;
    }
    // Function-like: needs an argument list, otherwise the name is left as is.
    let j = i;
    while (j < text.length && /\s/.test(text[j])) j++;
    if (text[j] !== "(") {
      out += name;
      continue;
    }
    const args = [];
    let depth = 0;
    let current = "";
    for (j = j + 1; j < text.length; j++) {
      const c = text[j];
      if (c === "(") depth++;
      if (c === ")" && depth-- === 0) break;
      if (c === "," && depth === 0) {
        args.push(current);
        current = "";
      } else {
        current += c;
      }
    }
    if (j >= text.length) throw new Error(`unterminated call to macro '${name}'`);
    args.push(current);
    i = j + 1;
    if (args.length !== macro.params.length && !(macro.params.length === 0 && args.join("").trim() === "")) {
      throw new Error(`macro '${name}' expects ${macro.params.length} argument(s), got ${args.length}`);
    }
    const expandedArgs = args.map((a) => expand(a.trim(), macros, active));
    const body = macro.body.replace(/[A-Za-z_]\w*/g, (id) => {
      const k = macro.params.indexOf(id);
      return k === -1 ? id : expandedArgs[k];
    });
    out += expand(body, macros, new Set([...active, name]));
  }
  return out;
}

function preprocess(src, predefined = {}) {
  const macros = new Map(Object.entries(predefined).map(([k, v]) => [k, { body: String(v) }]));
  const lines = stripComments(src).split("\n");
  const out = [];
  const stack = []; // { active, seenElse }
  const isActive = () => stack.every((s) => s.active);

  lines.forEach((line, n) => {
    const directive = line.match(/^\s*#\s*(\w+)\s*(.*)$/);
    if (!directive) {
      out.push(isActive() ? expand(line, macros) : "");
      return;
    }
    const [, name, rest] = directive;
    const where = `line ${n + 1}`;
    switch (name) {
      case "define": {
        if (!isActive()) break;
        const m = rest.match(/^([A-Za-z_]\w*)(\(([^)]*)\))?\s*(.*)$/);
        if (!m) throw new Error(`${where}: invalid #define`);
        const params = m[2] ? m[3].split(",").map((s) => s.trim()).filter(Boolean) : null;
        macros.set(m[1], { params, body: m[4].trim() });
        break;
      }
      case "undef":
        if (isActive()) macros.delete(rest.trim());
        break;
      case "ifdef":
      case "ifndef": {
        const defined = macros.has(rest.trim());
        stack.push({ active: name === "ifdef" ? defined : !defined, seenElse: false });
        break;
      }
      case "else": {
        const top = stack[stack.length - 1];
        if (!top || top.seenElse) throw new Error(`${where}: unexpected #else`);
        top.active = !top.active;
        top.seenElse = true;
        break;
      }
      case "endif":
        if (!stack.pop()) throw new Error(`${where}: unexpected #endif`);
        break;
      default:
        throw new Error(`${where}: unsupported directive #${name}`);
    }
    out.push("");
  });
  if (stack.length) throw new Error("unterminated #ifdef");
  return out.join("\n");
}

module.exports = { preprocess, stripComments };
