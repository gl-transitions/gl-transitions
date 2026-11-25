// What the benchmark's measures mean: cost relative to Fade, warning levels, calibration.
// Pure functions, shared by benchmark-transitions.mjs and calibrate-cost.mjs.

// The reference transition: one read of each image, the least a transition can do.
const REFERENCE = "Fade";

// The cost in ms of a 1080p frame on an Apple M1 Pro from which a transition gets a warning: a
// 60 fps frame is 16.7 ms, shared with the rest of the application, and on GPUs several times slower.
const WARNING_MS = { high: 4, "very high": 8 };

// The same limits relative to Fade, for each renderer. They come from the collection: see
// calibrate-cost.mjs (scripts/README.md, "Cost benchmark").
const LIMITS = {
  gpu: { high: 40, "very high": 80 },
  software: { high: 27, "very high": 43 },
};

const costLevel = (relative, limits) =>
  relative >= limits["very high"] ? "very high" : relative >= limits.high ? "high" : "normal";

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = sorted.length >> 1;
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
};

// Gives each measured transition the reference's cost, `fade`. `reports`: the measures in order,
// the references' ({ reference: true, ms }) among the transitions'.
// On the GPU, the fastest of the run: what else uses it only adds time, and Fade is so short that
// any of it shows. On the CPU, the median of the 3 on each side, which a drift of the runner's
// speed and a spike both leave right.
function attachReferences(reports, renderer) {
  // Fade costs the same at every progress.
  const references = reports.map(({ reference, ms }) => (reference ? Math.min(...ms) : null));
  const known = references.filter((v) => v !== null);
  const fastest = Math.min(...known);
  return reports.flatMap((report, i) => {
    if (report.reference) return [];
    if (report.error || !known.length) return [{ name: report.name, error: report.error ?? "no reference" }];
    const around = [
      ...references
        .slice(0, i)
        .filter((v) => v !== null)
        .slice(-3),
      ...references
        .slice(i)
        .filter((v) => v !== null)
        .slice(0, 3),
    ];
    return [{ ...report, fade: renderer === "gpu" ? fastest : median(around) }];
  });
}

// `measures`: [{ name, ms: [one per progress], fade: the reference's ms, around it }] or [{ name, error }].
// Worst frame first; the transitions that could not be measured are last.
function rankCosts(measures, limits) {
  return measures
    .map(({ name, ms, fade, error }) => {
      if (error) return { name, error };
      const worst = Math.max(...ms);
      const relative = worst / fade;
      return { name, ms, fade, worst, relative, level: costLevel(relative, limits) };
    })
    .sort((a, b) => (b.worst ?? -1) - (a.worst ?? -1) || a.name.localeCompare(b.name));
}

function formatTable(costs, progress) {
  const row = (name, ms, worst, relative, level) =>
    [name.padEnd(24), ...ms.map((v) => v.padStart(8)), worst.padStart(8), relative.padStart(9), ` ${level}`]
      .join(" ")
      .trimEnd();
  const number = (v) => v.toFixed(2);
  return [
    row("transition", progress.map(String), "worst", "x Fade", ""),
    ...costs.map(({ name, ms, worst, relative, level, error }) =>
      error
        ? `${name.padEnd(24)} not measured: ${error.split("\n")[0]}`
        : row(name, ms.map(number), number(worst), relative.toFixed(1), level === "normal" ? "" : level),
    ),
  ].join("\n");
}

// Ranks from 0, ties sharing their mean rank.
function ranks(values) {
  const order = values.map((_, i) => i).sort((a, b) => values[a] - values[b]);
  const result = [];
  for (let i = 0; i < order.length;) {
    let end = i;
    while (end < order.length && values[order[end]] === values[order[i]]) end++;
    for (let k = i; k < end; k++) result[order[k]] = (i + end - 1) / 2;
    i = end;
  }
  return result;
}

function spearman(a, b) {
  const [x, y] = [ranks(a), ranks(b)];
  const mean = (a.length - 1) / 2;
  let xy = 0;
  let xx = 0;
  let yy = 0;
  for (let i = 0; i < a.length; i++) {
    xy += (x[i] - mean) * (y[i] - mean);
    xx += (x[i] - mean) ** 2;
    yy += (y[i] - mean) ** 2;
  }
  return xy / Math.sqrt(xx * yy);
}

// How well `estimate >= limit` finds the transitions with `truth >= heavy`.
function detection(estimate, truth, limit, heavy) {
  const count = (test) => estimate.filter((e, i) => test(e >= limit, truth[i] >= heavy)).length;
  return {
    limit,
    found: count((flagged, isHeavy) => flagged && isHeavy),
    missed: count((flagged, isHeavy) => !flagged && isHeavy),
    wrong: count((flagged, isHeavy) => flagged && !isHeavy),
  };
}

// The limit on `estimate` that makes the fewest mistakes; the highest one of equals, since a wrong
// warning costs more than a missed one. Midway between two values, so that noise matters less;
// Infinity (no warning) when no limit does better.
function bestLimit(estimate, truth, heavy) {
  const sorted = [...new Set(estimate)].sort((a, b) => b - a);
  let best = detection(estimate, truth, Infinity, heavy);
  for (let i = 0; i < sorted.length - 1; i++) {
    const candidate = detection(estimate, truth, Math.sqrt(sorted[i] * sorted[i + 1]), heavy);
    if (candidate.missed + candidate.wrong < best.missed + best.wrong) best = candidate;
  }
  return best;
}

export {
  REFERENCE,
  WARNING_MS,
  LIMITS,
  costLevel,
  attachReferences,
  rankCosts,
  formatTable,
  spearman,
  detection,
  bestLimit,
};
