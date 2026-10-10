# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through [GitHub's private vulnerability reporting](https://github.com/gl-transitions/gl-transitions/security/advisories/new), not in a public issue or pull request.

This covers the `gl-transitions` npm package, the repository's CI workflows and tooling. Issues with gl-transitions.com or other repositories can be reported the same way; they will be forwarded.

## How the repository handles untrusted code

Pull requests contain shaders (and possibly scripts) from anyone, and every merge to `master` publishes to npm. The workflows are split along that trust boundary:

| Workflow | Runs PR code | Permissions |
|---|---|---|
| `CI` (build, test) | yes, on pull requests | read-only |
| `CI` (publish) | no: `master` only | `contents: write`, `id-token: write` (npm trusted publishing with provenance); dependencies installed without install scripts |
| `Preview`, `Reference renders`, `Test Preview` | yes | read-only, no secrets |
| `Preview Comment` | never: only reads the Preview artifact, validated as untrusted data | writes comments and the `preview-assets` branch |

Actions are pinned to commit SHAs and kept up to date by Dependabot.
