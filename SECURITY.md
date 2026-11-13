# Security Policy

Security Rules that agents **must** follow when working with this codebase.

## Supply-Chain Hygiene

**An agent must:**

- **Pin each dependency to an exact version when possible.** If you use a version constraint, it must allow patch updates only (for example `~1.2.3` in npm, `~> 1.2.3` in Terraform, `~=1.2.3` in Python). Do not use `^`, `>=`, `*`, `latest`, or constraints that allow minor or major updates.
- **Commit lock files** (for example `package-lock.json`, `uv.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`).
- **Install from the lock file only.** Use frozen installs such as `npm ci`, `uv sync --locked`, or `pip install --require-hashes`.
- **Pin GitHub Actions to a full commit SHA.** Put the version tag in a comment after the SHA.
- **Pin container images to a digest** (`image@sha256:...`), not only to a tag.
- **Pin infrastructure modules and providers** to an exact version or commit SHA.
- **Verify that a package exists** on its official registry before you add it. Check the name for typos and look-alike names. Never add a package name that you did not verify.
- **Prefer the standard library or an existing dependency** to a new dependency.
- **Tell the user** about each new dependency and the reason for it.
- **Never change dependency versions** as a side effect of other work. Upgrade only when the user asks.
- **Never pipe a remote script into a shell** (for example `curl ... | sh`).
- **Never disable integrity checks**, such as TLS verification, checksum verification, or signature verification.
