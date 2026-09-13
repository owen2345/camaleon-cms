## 1. Branch

- [x] 1.1 Create `fix/run-hook-handlers-once` from `master` per `docs/ai/workflows.md` Phase 1 (verify: `git branch --show-current`)

## 2. Reproduce (fails on master before section 3)

- [x] 2.1 Shared examples `spec/shared_specs/hook_handler_dispatch.rb`: a handler that raises after a side effect runs once and the error reaches the caller; a handler from a helper not yet included runs once; an undefined handler is skipped with a warning and the next handler still runs (verify: `bin/rspec spec/controllers/concerns/camaleon_cms/hook_lifecycle_concern_spec.rb spec/helpers/camaleon_cms/hooks_helper_spec.rb` fails on master)

## 3. Implement

- [x] 3.1 `HookLifecycleConcern#_do_hook` loads helpers when the handler is missing, warns and skips when it stays missing, and sends once (verify: the concern spec passes)
- [x] 3.2 `HooksHelper#_do_hook` gets the same dispatch (verify: the helper spec passes)

## 4. Documentation

- [x] 4.1 `docs/hooks.md` Mechanism: one paragraph on what a handler can expect from the dispatcher (verify: paragraph present)
- [x] 4.2 `CHANGELOG.md` entry under Unreleased after the PR exists (verify: `docs/ai/workflows.md` Phase 4.3)

## 5. Verify and close out

- [x] 5.1 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
- [x] 5.2 Run `/opsx:verify` and address its findings
- [x] 5.3 Run `/opsx:archive` on the branch and commit the archive in the PR (verify: `openspec/specs/hook-handler-dispatch/spec.md` exists, change moved under `openspec/changes/archive/`)

## 6. Review fixes (each spec fails before its fix)

- [x] 6.1 `HookLifecycleConcern` includes `HooksHelper` and drops its copies of `hook_run`, `hooks_run`, `hook_skip` and `_do_hook` (verify: the shared examples pass for both modules)
- [x] 6.2 The helper spec's own setup sits in a context of its own, and the shared examples call the public `hook_run`, count runs through `args` and share a default helper module (verify: the dispatch specs pass, `bin/rubocop`)
- [x] 6.3 A handler whose own code raises `NoMethodError` naming it runs once (verify: the example fails against a rescue narrowed to that error)
- [x] 6.4 `plugin_load_helpers` includes a helper into an object once however often it runs (verify: `spec/helpers/camaleon_cms/plugins_helper_spec.rb` fails before the fix)
- [x] 6.5 A plugin's helpers are included before its handlers run (verify: a handler named `format`, and `spec/requests/security/password_post_excerpt_leakage_spec.rb` run on its own, fail before the fix)
- [x] 6.6 A handler nothing defines raises `NoMethodError` and a handler served by `method_missing` runs, on both paths (verify: the shared examples fail before the fix)
- [x] 6.7 `docs/hooks.md`, `docs/upgrading-to-2.9.5.md`, `docs/ai/ecosystem.md` and the changelog entry match the behavior (verify: entry under 500 characters)
- [x] 6.8 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
