# Changesets

Each pull request that changes a published package (`packages/*`, and for `gl-transitions` also `skills/` and the build scripts) adds a changeset: run `pnpm changeset`, pick the packages and the bump, and describe the change for the changelog.

Transitions need none: when the "Version Packages" pull request is prepared, every transition added or changed since the last release gets one (`scripts/npm-package/write-transition-changesets.mjs`).

Merging the "Version Packages" pull request publishes the new versions. See [changesets](https://github.com/changesets/changesets).
