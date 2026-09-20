Every commit, push and PR below waits for the maintainer's explicit approval, one PR at a time. Member
repositories are edited by absolute path from the core working directory, their tooling run as
`(cd /Users/Shared/dev/ruby/<repo> && …)`. Spec runs are serialized, never two at once.

## 1. Pilot member: cama_contact_form

- [x] 1.1 From fresh `origin/master`, create `feature/core-compat-workflow`; verify `git status` is clean and the branch is reported to the maintainer
- [x] 1.2 Add the `CAMALEON_CMS_PATH` switch to `Gemfile` (non-empty → `path:`, else today's `'>= 2.9.4'` line); verify `bundle install` with the variable unset leaves `Gemfile.lock` byte-identical (`git diff --exit-code Gemfile.lock`)
- [x] 1.3 With `CAMALEON_CMS_PATH=../camaleon-cms`, run `bundle lock` and verify the lock diff moves `camaleon_cms` to a `PATH` source and changes no unrelated gem beyond what core master's gemspec requires; record any gem that moved
- [x] 1.4 With the variable still set, run `db:test:prepare` then `db:migrate` from `spec/dummy` and verify both succeed and that core's migrations are in the dummy's migration paths (design Decision 5); then run the full `bin/rspec` and verify 0 failures against core master
- [x] 1.5 Restore the workspace (`git checkout Gemfile.lock spec/dummy/db/schema.rb`, plain `bundle install`) and verify `git status` shows only the intended `Gemfile` edit
- [x] 1.6 Add `.github/workflows/core_compat.yml` per design Decisions 4 to 6 and 8 (`workflow_call` + `workflow_dispatch`, inputs `camaleon_cms_repository`, `camaleon_cms_ref`, `member_ref`; side-by-side checkouts; chromedriver; setup-ruby without bundler cache; `bundle lock`, print the lock diff, `actions/cache` on `vendor/bundle`, `bundle install`; DB prepare + migrate; `bundle exec rspec`); verify it parses with `ruby -ryaml` and, if `actionlint` is available, lints clean
- [x] 1.7 Add a CHANGELOG entry (newest first, 500 characters at most) and run the repository's full `bin/rubocop`; verify 0 offenses
- [x] 1.8 After approval: commit, push the branch, open the PR (description per `docs/ai/workflows.md` Phase 4), link it from the changelog entry; verify the member's own CI is green on the PR

## 2. Core workflow, proven against the pilot

- [x] 2.1 Add `.github/workflows/ecosystem.yml` on `feature/ecosystem-ci-cross-testing`: `pull_request` + push to `master`, `permissions: contents: read`, per-ref concurrency with cancel-in-progress, one `cama_contact_form` job calling the pilot workflow at its feature branch with `member_ref` set to that branch, passing `github.repository` and `github.sha`; verify it parses with `ruby -ryaml`
- [x] 2.2 After approval: commit without a skip-ci marker (this PR's proof is its own run), push, open the core PR; verify a `cama_contact_form / …` check appears on the PR, that its log shows core checked out at the PR's merge commit and the member at its feature branch, and that the suite passes
- [x] 2.3 If the run is refused by the repository's Actions policy or fails in setup, fix the member workflow on its branch and re-run until green; record in `design.md` anything that contradicted a decision

## 3. Remaining members, from the proven template

- [x] 3.1 `camaleon-cms-seo`: repeat 1.1 to 1.7 on `feature/core-compat-workflow` (no chromedriver step); verify the local suite is green against core master and the lock is restored
- [x] 3.2 `camaleon_editor`: repeat 1.1 to 1.7 (chromedriver step; clear `spec/dummy/tmp/cache` and `spec/dummy/public/assets` before the local run); verify the local suite is green against core master and the lock is restored
- [ ] 3.3 `florsan`: repeat 1.1 to 1.7 from fresh `origin/main` (Postgres 16 service with the credentials its `ci.yml` uses, `bin/rails db:test:prepare` + `db:migrate` from the app root, `bin/rspec`; no chromedriver); verify the local suite is green against core master and the lock is restored
- [ ] 3.4 After approval, one member at a time: commit, push, open its PR, add its job to core's `ecosystem.yml` at the member's feature branch, push core; verify that member's check appears on the core PR and passes, and that the other members' checks ran independently

## 4. Core documentation

- [ ] 4.1 `docs/ai/ecosystem.md`: add a cross-testing section listing the enrolled members, what a repository must provide to enroll (public, RSpec workflow, the three inputs, the Gemfile switch), that the checks are advisory and stay out of any future required set, and why `camaleon_website` is not enrolled; verify each spec requirement under "Enrollment is documented" is answered
- [ ] 4.2 `docs/ai/testing.md`: add how to reproduce a red member check locally (`CAMALEON_CMS_PATH`, `bundle lock`, migrate, run, restore the lock); verify the commands are the ones that passed in 1.3 to 1.5
- [ ] 4.3 Check `AGENTS.md`, `README.md` and `docs/releasing.md` for statements this change makes stale (the CI description, the Release workflow's required runs) and update only what is; verify with a grep for `current_support`, `workflows/` and `CI runs`

## 5. Flip to default branches and finish

- [ ] 5.1 Once the four member PRs are merged, point every `uses:` in `ecosystem.yml` at the member's default branch (`master`; `main` for `florsan`) and remove the `member_ref` inputs; verify with a grep that no feature-branch ref remains
- [ ] 5.2 Push that commit without a skip-ci marker and verify all four member checks pass on the core PR from the default branches
- [ ] 5.3 Add the core CHANGELOG entry under `## Unreleased` (Tooling, development-only, 500 characters at most, PR link); update the PR description to the net what/why
- [ ] 5.4 Run core's pre-push checks: `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`; no specs are added because the change is CI configuration and docs only, and the PR says so; verify all three pass
- [ ] 5.5 Run `/opsx:verify`, then `/opsx:archive` on the branch and commit the result; verify `openspec/specs/ecosystem-cross-testing/spec.md` exists and `openspec list --json` shows no active change
- [ ] 5.6 Self-audit against `docs/ai/criteria.md`; update the `ecosystem-ci-cross-testing-plan` memory to reflect what shipped
