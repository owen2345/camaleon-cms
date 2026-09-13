## 1. Failing specs (`meta-storage-integrity`)

- [x] 1.1 Create `spec/models/meta_default_spec.rb` with examples for "Each read of a meta with no value returns its caller's default":
  - a post with no `gallery` meta, read without a default and then with `[]`: on the post itself, on a freshly loaded post, and on a post loaded with `includes(:metas)`;
  - an empty-array default that the caller appends to in place, followed by another read with `[]`;
  - a stored empty-string row, read without a default and then with a default;
  - three reads of a missing meta on a post loaded without its metas, counted with `sql_queries(matching: /metas/)`.

  Verify with `bin/rspec spec/models/meta_default_spec.rb` that the first three examples fail on the current code. The query-count example passes, because it pins the query profile the fix keeps.
- [x] 1.2 In the same file, add an example for "A meta written as an empty string": `set_meta` with `''`, then `get_meta` with a default on the same instance and on a reloaded post. Verify that the same-instance read fails on the current code.

## 2. get_meta

- [x] 2.1 In `app/models/concerns/camaleon_cms/metas.rb`, change `get_meta` as design.md decides:
  - the memoized block returns the stored lookup, with `''` when there is no row or the stored value is empty;
  - outside `cama_fetch_cache`, return the caller's default when the memoized value is `''`.

  Update the method's comment, and leave `set_meta`, `options` and `CamaleonRecord` unchanged. Verify that the section 1 examples pass, and that `spec/models/meta_spec.rb`, `meta_duplicate_rows_spec.rb`, `meta_pending_create_spec.rb` and `meta_scope_resolution_spec.rb` pass.

## 3. Docs

- [x] 3.1 In `docs/upgrading-to-2.9.5.md`, add a subsection under "Notes for theme & plugin developers" saying that:
  - `get_meta` returns each call's own default;
  - a later read does not see a default changed in place unless it was written with `set_meta`;
  - `set_meta(key, '')` reads as the default on the writing instance.

  Add a matching row to "At a glance", and verify that the row's link resolves to the new subsection's anchor.
- [x] 3.2 In `docs/ai/ecosystem.md`, under "Hardening hazards", add an entry recording the `get_meta` caller review. It covers the consumers that change a returned default in place and pass it to `set_meta`, and `camaleon-ecommerce`'s `LegacyOrder` reads. Verify that the consumers it names match design.md's "Risks / Trade-offs".

## 4. Verification and delivery

- [x] 4.1 Rebase on `master` if any of `fix/same-instance-option-reads`, #1298, #1299 or #1301 has merged, resolving conflicts in `metas.rb` and in `openspec/specs/meta-storage-integrity/spec.md`. If `fix-same-instance-option-reads` is already archived, add a MODIFIED delta to this change that trims "a get_meta read without a default left nil" from its requirement "Options that are nil or empty read and write as none". Verify that `bin/rspec spec/models` passes after the rebase.
- [x] 4.2 Run the CI-parity commands from `AGENTS.md` and verify all four pass: `bin/rspec`, `bin/rubocop -A` on touched files followed by a full `bin/rubocop` with no offenses, `bin/brakeman --no-pager`, and `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 4.3 Commit the specs, fix and docs, push `fix/get-meta-default-per-call`, and open the PR with a What and Why summary and a User-Visible Impact sentence (`docs/ai/workflows.md` Phase 4). Verify that the PR's CI run starts.
- [x] 4.4 Add a `CHANGELOG.md` entry under `## Unreleased` that links the PR and the upgrade-guide anchor. Verify that it is at most 500 characters.
- [x] 4.5 Run `/opsx:verify` and address its findings.
- [x] 4.6 Run `/opsx:archive` on the branch, syncing both requirement changes into `openspec/specs/meta-storage-integrity/spec.md`. Commit the result together with the changelog entry, using the skip-ci directive once the PR has had a full run (`docs/ai/workflows.md` Phase 3). Verify that every box in this file is checked.
