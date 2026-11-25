import { execFileSync } from "node:child_process";
import fs from "node:fs";

// The date each file of dir was first added to git, followed through its renames: { file: date }.
export function getCreationDates(dir) {
  const git = (...args) => execFileSync("git", args, { cwd: dir, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  const prefix = git("rev-parse", "--show-prefix").trim();
  const created = {};
  // The path each file had at the commit being read, newest to oldest → its current name.
  const tracked = new Map(fs.readdirSync(dir).map((file) => [prefix + file, file]));

  // The whole directory: limited to the current names, git would show a rename as an addition.
  const log = git("log", "--topo-order", "-M", "-l0", "--diff-filter=AR", "--format=@%aD", "--name-status", "--", ".");
  let date;
  for (const line of log.split("\n")) {
    if (line.startsWith("@")) {
      date = line.slice(1);
      continue;
    }
    const [status, from, to] = line.split("\t");
    const file = tracked.get(to ?? from);
    if (!file) continue;
    tracked.delete(to ?? from);
    if (status === "A") created[file] = date;
    else tracked.set(from, file);
  }
  return created;
}
