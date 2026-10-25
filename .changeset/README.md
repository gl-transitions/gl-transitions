# Changesets

Each pull request that changes a published package (`packages/*`, and for `gl-transitions` also `skills/` and the build scripts; the Rust crate `crates/gl-transitions` and `scripts/rust-crate/` as `gl-transitions-crate`) adds a changeset: run `pnpm changeset`, pick the packages and the bump, and describe the change for the changelog.

A `package.json` change that only touches `devDependencies` needs none (Dependabot bumps them; they are not published).

Transitions need none: when the "Version Packages" pull request is prepared, every transition added or changed since the last release gets one (`scripts/npm-package/write-transition-changesets.mjs`).

Merging the "Version Packages" pull request publishes the new versions (the crate to crates.io; every `gl-transitions` release bumps its patch version, see CONTRIBUTING.md). See [changesets](https://github.com/changesets/changesets).
