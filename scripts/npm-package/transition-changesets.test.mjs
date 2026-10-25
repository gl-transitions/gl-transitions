// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { transitionChangesets } from "./transition-changesets.mjs";

test("transition changesets: one per new transition, crediting its author", () => {
  const [file] = transitionChangesets([{ status: "A", name: "swirl", author: "Jane Doe", commit: "abc123" }]);
  assert.deepEqual(file, {
    file: "transition-swirl.md",
    content: '---\n"gl-transitions": minor\n---\n\ncommit: abc123\n\nNew transition: `swirl` by Jane Doe.\n',
  });
});

test("transition changesets: changed and removed transitions are grouped by commit", () => {
  const many = ["a", "b", "c", "d", "e", "f"].map((name) => ({ status: "M", name, commit: "0123456789abcdef" }));
  const files = transitionChangesets([
    { status: "M", name: "fade", commit: "def456" },
    { status: "M", name: "cube", commit: "def456" },
    ...many,
    { status: "D", name: "old" },
  ]);
  assert.deepEqual(
    files.map((f) => f.file),
    ["transitions-updated-def456.md", "transitions-updated-0123456789ab.md", "transitions-removed-old.md"],
  );
  assert.match(files[0].content, /commit: def456\n\nUpdated `fade`, `cube`\.\n$/);
  assert.match(files[1].content, /Updated 6 transitions\.\n$/);
  assert.match(files[2].content, /---\n\nRemoved `old`\.\n$/);
});

test("write-transition-changesets: credits a new transition to the commit that added it", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "transition-changesets-"));
  try {
    const git = (...args) =>
      execFileSync("git", ["-c", "user.name=t", "-c", "user.email=t@t", ...args], {
        cwd: root,
        encoding: "utf8",
      }).trim();
    const write = (file, content) => {
      fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
      fs.writeFileSync(path.join(root, file), content);
    };
    const glsl = (body) => `// Author: Jane\n// License: MIT\nvec4 transition(vec2 uv) { return ${body}; }\n`;
    git("init", "-q");
    write("packages/gl-transitions/package.json", '{ "version": "1.0.0" }\n');
    write(".changeset/config.json", "{}\n");
    write("transitions/fade.glsl", glsl("getFromColor(uv)"));
    write("transitions/old_wipe.glsl", glsl("getToColor(uv)"));
    write("transitions/old_slide.glsl", glsl("getToColor(uv)"));
    git("add", ".");
    git("commit", "-qm", "1.0.0");
    git("tag", "v1.0.0");
    write("transitions/swirl.glsl", glsl("getToColor(uv)"));
    git("add", ".");
    git("commit", "-qm", "add swirl");
    const added = git("rev-parse", "HEAD");
    write("transitions/swirl.glsl", glsl("getToColor(uv * 0.5)"));
    write("transitions/fade.glsl", glsl("getToColor(uv)"));
    git("commit", "-qam", "edit swirl and fade");
    const edited = git("rev-parse", "HEAD");
    write("transitions/fade.glsl", glsl("getToColor(uv * 2.0)"));
    git("commit", "-qam", "edit fade again");
    const again = git("rev-parse", "HEAD");

    // A rename is neither a new nor a removed transition; it is updated only when its content
    // changed too. A new transition renamed before the release keeps the credit of the commit that
    // added it.
    git("mv", "transitions/old_wipe.glsl", "transitions/Wipe.glsl");
    git("mv", "transitions/old_slide.glsl", "transitions/Slide.glsl");
    write("transitions/Slide.glsl", glsl("getToColor(uv)") + "// Description: Slides in\n");
    git("mv", "transitions/swirl.glsl", "transitions/Swirl.glsl");
    git("add", ".");
    git("commit", "-qm", "rename transitions");
    const renamedAt = git("rev-parse", "HEAD");

    execFileSync("node", [path.join(import.meta.dirname, "write-transition-changesets.mjs"), root]);
    const read = (file) => fs.readFileSync(path.join(root, ".changeset", file), "utf8");
    const written = fs.readdirSync(path.join(root, ".changeset"));
    assert.ok(!written.some((f) => /Wipe|old_wipe/.test(f) || /Wipe|old_wipe/.test(read(f))), written.join(", "));
    assert.match(read(`transitions-updated-${renamedAt.slice(0, 12)}.md`), /Updated `Slide`\./);
    assert.match(read("transition-Swirl.md"), new RegExp(`commit: ${added}\n\nNew transition: \`Swirl\` by Jane\\.`));
    // fade is listed under both commits that changed it.
    assert.match(read(`transitions-updated-${edited.slice(0, 12)}.md`), /Updated `fade`\./);
    assert.match(read(`transitions-updated-${again.slice(0, 12)}.md`), /Updated `fade`\./);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
