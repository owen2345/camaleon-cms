# Camaleon CMS: Agent Entry Point

Camaleon CMS is a Rails engine shipped as the `camaleon_cms` gem. Everything below applies to every task; load the documents in the table only when the task calls for them.

## Ground rules

- **Gem, not an app.** Root `bin/rails` only runs engine commands. Run app commands (`routes`, `zeitwerk:check`, …) from the dummy app in a subshell: `(cd spec/dummy && bin/rails …)`.
- **Support range.** CI runs Rails 7.1 through 8.1 on Ruby 3.2 through 4.0 (`gemfiles/`, `.github/workflows/`); the gemspec floor is Rails 6.1. Use framework and language APIs that hold across that range.
- **Branch first.** Prefix `feature/`, `fix/` or `security/` before writing code (`docs/ai/workflows.md` Phase 1).
- **Specs.** Code changes ship with specs; behavior-preserving refactors and docs/config-only changes are exempt. Say so when a test is infeasible. A vulnerability fix starts with a spec that reproduces it, request or feature over controller (triage: `docs/ai/workflows.md` Phase 2A; templates: `docs/ai/testing.md`).
- **Security remedy: reject, don't transform.** Content and uploads from untrusted users are scanned and refused at save, never sanitized, stripped or escaped, at save or at render. What passes is stored and served verbatim, so no header, CSP, content-disposition or separate origin may constrain it either: a control that would constrain a trusted user's content is out. Admins can do anything. For other roles prefer the scan; a dedicated default-off permission is the remedy only where no scan can reach a verdict (uploaded JavaScript). Model: `docs/security/permissions.md`.
- **Ecosystem.** Most plugins and themes are separate gems; `README.md` lists the known ones and more exist. A public helper's contract cannot be verified from this repo, so consult `docs/ai/ecosystem.md` before removing, renaming or hardening one.

## Verify before pushing

`bin/rspec`, `bin/rubocop -A` (auto-correct only what you touched), `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`. All four, CI parity.

## OpenSpec

Plan with OpenSpec (`/opsx:explore`, `/opsx:propose` or `/opsx:new`, then `/opsx:apply`, `/opsx:verify`, `/opsx:archive`) when work has non-trivial behavior, contract or cross-cutting concerns; work directly on trivial or documentation-only changes. Run `openspec list --json` first and continue a matching active change instead of opening a duplicate. Archive on the branch, before merge, committed in the PR (`docs/ai/workflows.md` Phase 4). Lasting decisions go in the change's `design.md`; durable behavior becomes requirements in `openspec/specs/`, not journals under `docs/`.

## Load per task

| Task | Load |
|---|---|
| Branching, vulnerability triage, refactoring protocol, commits, PRs, changelog | `docs/ai/workflows.md` |
| Writing or running tests; reproducing vulnerabilities | `docs/ai/testing.md` |
| Reading or writing app code: paths, namespacing, decorators, hooks, plugins, idioms | `docs/ai/reference.md` |
| Removing, renaming or hardening a public helper, hook or API | `docs/ai/ecosystem.md` |
| Env files, keys, credentials | `docs/ai/secrets.md` |
| Self-audit before opening a PR | `docs/ai/criteria.md` |
| Cutting a release | `docs/releasing.md` |
