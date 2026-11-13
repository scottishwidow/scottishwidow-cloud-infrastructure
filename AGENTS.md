# Agent Workflow Guidelines

This file defines how coding agents should operate in this repository.

## User Interaction & Documentation Standards

**An agent must:**

- **Be concise.** Write in ASD-STE100 Simplified Technical English.
- **Never use emojis** in Markdown documentation.
- **Write well-structured documentation** with appropriate headings.
- **Never document** anything unless asked specifically to do so.

## Code Comments

**An agent must:**

- **Write self-documenting code.** Name variables and functions so a comment that restates them is unnecessary.
- **Never reference** chats, PRs, or change logs inside code files.
- **Use comments only when required**, for example:
  - `TODO`/`FIXME` markers tracking outstanding work
  - A short note where behavior is genuinely non-obvious and cannot be made clear by the code itself
- **Keep existing comments.** Update a comment when you change the code it describes. Remove a comment only when it is wrong or obsolete.

## AI Policy

This repo has an `AI_POLICY.md` in `.github/`. When helping a contributor open a PR or issue, point them to it. Key points: contributor owns every line, slop gets closed without discussion.

## Security

Before adding, removing, or changing a dependency, read `SECURITY.md` and obey its supply-chain rules.

## Git

**An agent must:**

- **Work in a git worktree.** Before you change files, make sure the session runs in a worktree. If it does not, create a worktree on a new branch for the task. Make all changes in the worktree, never in the main checkout.
- **Stay inside the worktree.** The worktree is the repository. Use relative paths. Files outside the worktree belong to a different branch and give stale results.
- **Treat files you did not create as work of another session.** Several agent sessions can share one worktree. Ask the user before you delete, reset, or discard such files, including untracked files.
- **Ask the user how to continue** when a pre-commit hook fails on files you did not touch.
- **Get explicit user approval before a destructive git command**, for example `git reset --hard`, `git checkout -- .`, `git restore .`, `git clean`, `git stash drop`, or `git push --force`.
- **Commit only project files**: code, tests, requested documentation, and schemas. Keep to-do lists, research notes, and scratch files out of commits.
- **Let pre-commit hooks run.** Fix the cause of a hook failure. Never use `--no-verify`.
- **Check <https://www.githubstatus.com/>** before you retry or change anything after an unexplained git or GitHub failure.
- **Fix review findings and incomplete work in the open PR.** Open a follow-up issue only for work deferred from a feature that is already merged.

---

## Terraform

**An agent must:**

- **Never allow** `.terraform/` or `.terraform.lock.hcl` inside submodules. These files are permitted only at the root module level.
- **Never apply Terraform.** Only CI or a human can apply Terraform.
- **Never create** standalone resources in root modules. Use an existing submodule or an open-source module (for example, [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules)).
- **Create a custom submodule** only if no open-source module meets the need.

### Issue tracker

Issues live in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Multi-context (monorepo) layout with CONTEXT-MAP.md at the root. See `docs/agents/domain.md`.
