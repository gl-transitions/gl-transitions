// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  LIMITS,
  attachReferences,
  bestLimit,
  costLevel,
  detection,
  formatTable,
  rankCosts,
  spearman,
} from "./frame-cost.mjs";

const limits = { high: 10, "very high": 20 };

test("frame cost: levels start at their limit", () => {
  assert.deepEqual(
    [1, 9.9, 10, 19.9, 20, 500].map((relative) => costLevel(relative, limits)),
    ["normal", "normal", "high", "high", "very high", "very high"],
  );
  for (const { high, "very high": veryHigh } of Object.values(LIMITS)) assert.ok(1 < high && high < veryHigh);
});

test("frame cost: the worst frame counts, worst transition first, unmeasured ones last", () => {
  const costs = rankCosts(
    [
      { name: "Broken", error: "no such function\nmore" },
      { name: "Light", ms: [0.5, 1], fade: 0.5 },
      { name: "Heavy", ms: [1, 12, 2], fade: 0.5 },
    ],
    limits,
  );
  assert.deepEqual(
    costs.map(({ name, worst, relative, level }) => [name, worst, relative, level]),
    [
      ["Heavy", 12, 24, "very high"],
      ["Light", 1, 2, "normal"],
      ["Broken", undefined, undefined, undefined],
    ],
  );
  const lines = formatTable([costs[0], costs[2]], [0.1, 0.5, 0.9]).split("\n");
  assert.match(lines[0], /^transition +0\.1 +0\.5 +0\.9 +worst +x Fade$/);
  assert.match(lines[1], /^Heavy +1\.00 +12\.00 +2\.00 +12\.00 +24\.0 +very high$/);
  assert.match(lines[2], /^Broken +not measured: no such function$/);
});

test("frame cost: references are the fastest of the run on a GPU, the median around on a CPU", () => {
  const fade = (ms) => ({ reference: true, ms: [ms, ms * 2] });
  const reports = [
    ...[1, 2, 9].map(fade),
    { name: "A", ms: [10] },
    fade(3),
    { name: "B", error: "broken" },
    ...[4, 5].map(fade),
    { name: "C", ms: [20] },
    fade(40),
  ];
  const fades = (renderer) => attachReferences(reports, renderer).map(({ name, fade, error }) => [name, fade ?? error]);
  assert.deepEqual(fades("gpu"), [
    ["A", 1],
    ["B", "broken"],
    ["C", 1],
  ]);
  assert.deepEqual(fades("software"), [
    ["A", 3.5],
    ["B", "broken"],
    ["C", 4.5],
  ]);
  assert.deepEqual(attachReferences([{ name: "A", ms: [10] }], "gpu"), [{ name: "A", error: "no reference" }]);
});

test("frame cost: Spearman correlation compares ranks, ties included", () => {
  assert.equal(spearman([1, 2, 3, 4], [10, 100, 1000, 10000]), 1);
  assert.equal(spearman([1, 2, 3, 4], [4, 3, 2, 1]), -1);
  assert.ok(Math.abs(spearman([1, 2, 2, 3], [1, 2, 3, 4]) - Math.sqrt(0.9)) < 1e-12);
});

test("frame cost: the best limit separates the heavy transitions", () => {
  const estimate = [1, 2, 4, 16, 64];
  assert.deepEqual(bestLimit(estimate, [1, 1, 1, 9, 9], 8), { limit: 8, found: 2, missed: 0, wrong: 0 });
  assert.deepEqual(detection(estimate, [9, 1, 1, 1, 9], 10, 8), { limit: 10, found: 1, missed: 1, wrong: 1 });
  // Missing one and warning wrongly about one are as bad: the highest limit wins.
  assert.equal(bestLimit([1, 2, 4, 16], [1, 9, 1, 9], 8).limit, 8);
  assert.equal(bestLimit(estimate, [1, 1, 1, 1, 1], 8).limit, Infinity);
});
