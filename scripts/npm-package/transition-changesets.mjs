// The changesets of the transitions changed since the last release of gl-transitions, so that
// contributors (often on GitHub's web editor) don't have to write them. See
// write-transition-changesets.mjs.

const MINOR = '---\n"gl-transitions": minor\n---\n\n';
const list = (names) => (names.length > 5 ? `${names.length} transitions` : names.map((n) => `\`${n}\``).join(", "));

// `changes`: [{ status: "A" | "M" | "D", name, author, commit }], from `git diff --name-status`.
// Returns [{ file, content }] for the .changeset folder, all minor releases. Each new transition
// gets its own entry, crediting its author; changed and removed ones are grouped by commit (a
// change to many transitions at once is one entry). The `commit:` line lets the changelog link
// the pull request.
function transitionChangesets(changes) {
  const files = [];
  const groups = new Map();
  for (const { status, name, author, commit } of changes) {
    if (status === "A") {
      files.push({
        file: `transition-${name}.md`,
        content: `${MINOR}${commit ? `commit: ${commit}\n\n` : ""}New transition: \`${name}\`${author ? ` by ${author}` : ""}.\n`,
      });
      continue;
    }
    const key = `${status} ${commit ?? ""}`;
    if (!groups.has(key)) groups.set(key, { status, commit, names: [] });
    groups.get(key).names.push(name);
  }
  for (const { status, commit, names } of groups.values()) {
    const what = status === "D" ? "Removed" : "Updated";
    files.push({
      file: `transitions-${status === "D" ? "removed" : "updated"}-${commit ? commit.slice(0, 12) : names[0]}.md`,
      content: `${MINOR}${commit ? `commit: ${commit}\n\n` : ""}${what} ${list(names)}.\n`,
    });
  }
  return files;
}

export { transitionChangesets };
