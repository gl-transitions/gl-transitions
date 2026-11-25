import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { getCreationDates } from "./creation-dates.mjs";

const source = (name) => Array.from({ length: 20 }, (_, i) => `// ${name} line ${i}\n`).join("");

test("creation dates follow renames, moves and edits", (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "creation-dates-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const dir = path.join(root, "transitions");
  const write = (file, text) => {
    fs.mkdirSync(path.dirname(path.join(dir, file)), { recursive: true });
    fs.writeFileSync(path.join(dir, file), text);
  };
  // In a git hook, GIT_DIR points to the real repository.
  const env = Object.fromEntries(Object.entries(process.env).filter(([name]) => !name.startsWith("GIT_")));
  const git = (...args) => execFileSync("git", args, { cwd: root, env });
  // Each commit replaces the whole directory: git finds the renames by content.
  const commit = (year, files) => {
    fs.rmSync(dir, { recursive: true, force: true });
    for (const [file, text] of Object.entries(files)) write(file, text);
    // On a case-insensitive disk, adding Cube.glsl would keep cube.glsl in the index.
    git("read-tree", "--empty");
    git("add", "-A");
    git(
      ...["-c", "user.name=a", "-c", "user.email=a@example.com", "-c", "commit.gpgsign=false", "commit", "-q"],
      ...["-m", `${year}`, `--date=${year}-06-01T00:00:00Z`],
    );
  };
  git("init", "-q");
  git("config", "core.ignorecase", "false");

  commit(2017, {
    "cube.glsl": source("cube"),
    "leaf.glsl": source("leaf"),
    "nested.glsl/nested.glsl": source("nested"),
    "Reused.glsl": source("old"),
  });
  commit(2018, { "cube.glsl": source("cube"), "leaf.glsl": source("leaf"), "nested.glsl": source("nested") });
  commit(2019, {
    "Cube.glsl": source("cube"),
    "LeafWipe.glsl": source("leaf") + "// edited\n",
    "nested.glsl": source("nested"),
  });
  commit(2020, {
    "Cube.glsl": source("remastered"),
    "LeafWipe.glsl": source("leaf"),
    "nested.glsl": source("nested"),
    "Reused.glsl": source("reused"),
    "New.glsl": source("new"),
  });

  const years = Object.fromEntries(
    Object.entries(getCreationDates(dir)).map(([file, date]) => [file, new Date(date).getUTCFullYear()]),
  );
  assert.deepEqual(years, {
    "Cube.glsl": 2017,
    "LeafWipe.glsl": 2017,
    "nested.glsl": 2017,
    "New.glsl": 2020,
    "Reused.glsl": 2020,
  });
});
