# Camaleon CMS: Agent Entry Point

Camaleon CMS is a Rails engine shipped as the `camaleon_cms` gem. Everything below applies to every task; load the documents in the table only when the task calls for them.

## Ground rules

- **Gem, not an app.** Root `bin/rails` only runs engine commands. Run app commands (`routes`, `zeitwerk:check`, …) from the dummy app in a subshell: `(cd spec/dummy && bin/rails …)`.
- **Support range.** CI runs Rails 7.1 through 8.1 on Ruby 3.2 through 4.0 (`gemfiles/`, `.github/workflows/`); the gemspec floor is Rails 6.1. Use framework and language APIs that hold across that range. The two rules above are the gem's: a host app has no dummy, and it runs the one Rails and Ruby that it pins.
- **Branch first.** Prefix `feature/`, `fix/` or `security/` before writing code (`docs/ai/workflows.md` Phase 1).
- **Specs.** Code changes ship with specs; behavior-preserving refactors and docs/config-only changes are exempt. Say so when a test is infeasible. A vulnerability fix starts with a spec that reproduces it, request or feature over controller (triage: `docs/ai/workflows.md` Phase 2A; templates: `docs/ai/testing.md`).
- **Security remedy: reject, don't transform.** Content and uploads from untrusted users are scanned and refused at save, never sanitized, stripped or escaped, at save or at render. What passes is stored and served verbatim, so no header, CSP, content-disposition or separate origin may constrain it either: a control that would constrain a trusted user's content is out. Admins can do anything. For other roles prefer the scan; a dedicated default-off permission is the remedy only where no scan can reach a verdict (uploaded JavaScript). Model: `docs/security/permissions.md`.
- **Ecosystem.** Most plugins and themes are separate gems; `README.md` lists the known ones and more exist. A public helper's contract cannot be verified from this repo, so consult `docs/ai/ecosystem.md` before removing, renaming or hardening one.
- **Prose.** A reader must understand all prose easily, and this rule comes before the other prose rules. All prose follows ASD-STE100 Simplified Technical English and is concise. This applies to code comments, new commit messages, PR titles and descriptions, the descriptions of new specs, and any Markdown file (`docs/ai/prose.md`).

## Verify before pushing

`bin/rubocop -A` (before the specs, since autocorrect can change behavior), `bin/rspec <the specs the PR adds or changes, plus the adjacent ones>`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`. The lint runs on the whole repo, as CI lints it, and never on a list of files. With a list of files, RuboCop also corrects a listed file that `.rubocop.yml` excludes. All four, unless the branch changes no code. A branch changes no code when it touches only Markdown files, in any folder, files under `openspec/` and git settings such as `.gitignore`.

Before a commit, the same rule applies to the code files of that commit (`docs/ai/workflows.md` Phase 3): its no-code files do not count. A commit whose code files are all under `spec/`, outside `spec/dummy`, runs the lint and the specs: brakeman and zeitwerk:check read no spec file.

Adjacent specs are those of the code that the PR touches: the same model, concern, controller or helper. For a changed factory or support file, they are the specs that use the factories or helpers that it changes. For a base class or a concern, they also include the specs of every class that inherits or includes it. For a controller or a view, they also include the specs that send a request that it answers or that renders it.

A grep of `spec/` (`grep -rlF --exclude-dir=dummy -e '<a>' -e '<b>' spec/`) for the changed symbols and for those class names finds them: the `*_spec.rb` hits are the specs. A hit in `spec/support` or `spec/shared_specs` that holds a request points at the specs that use its shared context or helper. For a controller or a view, also grep for its route helpers and the path segment that names its resource. `(cd spec/dummy && bin/rails routes -c 'comments|posts')`, with bare names without `Controller`, or `bin/rails routes` at the root of a host app, lists both for the controllers of a PR. A shared segment such as `admin` names no resource.

For a route with no such segment, such as the frontend `/:slug`, `Rails.application.routes.recognize_path(<path>, method: <verb>)` names the controller of a request that a spec sends. A bundled plugin of `app/apps/plugins` has routes only when a site of the dummy database has it installed. Grep for its slug instead. When the adjacent set is more than half of the suite, run the whole suite instead: it costs the same.

Run the whole suite only in these cases:

- The user asks for it.
- You reproduce a failed CI job (`docs/ai/failures.md`).
- The adjacent set is more than half of the suite (above).

To debug a spec failure, follow `docs/ai/failures.md` too. CI runs the whole suite on every push.

A commit that touches `openspec/` also runs `openspec validate --all --strict` and `openspec validate --archived`. `--specs` alone skips a change not yet archived, and `--all` skips an archived one. Only `--archived` checks that an archived change has every task checked (Phase 4). Given both flags, `validate` runs only the archived set.

A push needs no new check run when each of its commits ran the checks first, or was exempt from them (`docs/ai/workflows.md` Phase 3). An autosquash rebase keeps the tree of the last commit. A rebase onto the base changes that tree, so the checks run again before the push.

## OpenSpec

Plan with OpenSpec (`/opsx:explore`, `/opsx:propose` or `/opsx:new`, then `/opsx:apply`, `/opsx:verify`, `/opsx:archive`) when work has non-trivial behavior, contract or cross-cutting concerns; work directly on trivial or documentation-only changes. Run `openspec list --json` first and continue a matching active change instead of opening a duplicate. Archive on the branch, before merge, committed in the PR (`docs/ai/workflows.md` Phase 4). Lasting decisions go in the change's `design.md`; durable behavior becomes requirements in `openspec/specs/`, not journals under `docs/`.

## Load per task

| Task | Load |
|---|---|
| Branching, vulnerability triage, refactoring protocol, commits, PRs, changelog | `docs/ai/workflows.md` |
| Writing or running tests; reproducing vulnerabilities | `docs/ai/testing.md` |
| Debugging a failed check: the second run, the bisect, a failed CI job | `docs/ai/failures.md` |
| Reading or writing app code: paths, namespacing, decorators, hooks, plugins, idioms | `docs/ai/reference.md` |
| Removing, renaming or hardening a public helper, hook or API | `docs/ai/ecosystem.md` |
| Env files, keys, credentials | `docs/ai/secrets.md` |
| Self-audit before opening a PR | `docs/ai/criteria.md` |
| Cutting a release | `docs/releasing.md` |
