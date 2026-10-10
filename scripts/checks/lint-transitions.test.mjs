// Run with: npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { checkEncoding } from "./encoding.mjs";
import { lintTransitions } from "./lint-transitions.mjs";

const ok = "// Author: a\n// License: MIT\nvec4 transition(vec2 uv) { return getToColor(uv); }\n";

test("checkEncoding: valid UTF-8 with LF, including a literal U+FFFD, passes", () => {
  assert.deepEqual(checkEncoding(Buffer.from(ok + "// � é\n")), []);
});

test("checkEncoding: BOM, invalid UTF-8, CRLF and bare CR", () => {
  assert.match(checkEncoding(Buffer.from("﻿" + ok))[0], /byte order mark/);
  assert.match(checkEncoding(Buffer.from([0x2f, 0x2f, 0xe9, 0x0a]))[0], /UTF-8/);
  assert.match(checkEncoding(Buffer.from(ok.replace(/\n/g, "\r\n")))[0], /carriage return/);
  assert.match(checkEncoding(Buffer.from(ok.replace(/\n/g, "\r")))[0], /carriage return/);
});

test("lintTransitions: layout errors; hidden files are ignored", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "lint-"));
  fs.writeFileSync(path.join(dir, "Good.glsl"), ok);
  fs.writeFileSync(path.join(dir, ".DS_Store"), "x");
  fs.writeFileSync(path.join(dir, "NoExtension"), ok);
  fs.mkdirSync(path.join(dir, "Nested.glsl"));
  fs.writeFileSync(path.join(dir, "Nested.glsl", "Nested.glsl"), ok);
  const { count, errors } = lintTransitions(dir);
  assert.equal(count, 3);
  assert.equal(errors.length, 2);
  assert.ok(errors.some((e) => /NoExtension: must have the \.glsl extension/.test(e)));
  assert.ok(errors.some((e) => /Nested\.glsl: must be a file directly in transitions\//.test(e)));
  fs.rmSync(dir, { recursive: true });
});
