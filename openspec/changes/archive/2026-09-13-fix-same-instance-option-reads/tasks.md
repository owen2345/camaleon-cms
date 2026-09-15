## 1. Failing specs (`meta-storage-integrity`)

- [x] 1.1 In `spec/models/meta_spec.rb` ("options and hash metas on the instance that wrote them"), add examples for "Option reads on the writing instance find either key type":
  - a plain Hash holding a String `color` and a Symbol `size` passed to `set_meta`, read through `options` and `get_option` by the other key type on the same instance and after a reload, with `get_meta` still returning the caller's hash with its own keys;
  - request parameters holding `color` passed to `set_meta`, read through `options` by both key types and through `get_option`.

  Verify with `bin/rspec spec/models/meta_spec.rb` that both examples fail on the current code: it returns a plain Hash as passed, and its options-row rule reads request parameters as no options on the writing instance, so the reads `camaleon-ecommerce` relies on find nothing there.
- [x] 1.2 In the same block, add examples for "Options that are nil or empty read and write as none":
  - a post with no options row, its options read with `get_meta` without a default first, followed by `options`, `get_option` with a default and `set_option` on the same instance, checked there and after a reload;
  - `set_meta` with nil and with an empty string, with `options` empty and `get_option` returning the default on the same instance and on a freshly loaded post, and an option set on the freshly loaded post read by a post loaded afterwards.

  They pass on the current code, whose options-row rule already reads a cached nil or empty string as no options; they pin that on the writing instance.

## 2. Option API

- [x] 2.1 In `app/models/concerns/camaleon_cms/metas.rb`, have `options` convert what `get_meta` returns, as design.md decides:
  - an indifferent hash as it is;
  - request parameters as an indifferent copy through `to_unsafe_h`;
  - a JSON string as the parsed object, copied as a plain Hash is;
  - a plain Hash as an indifferent copy that shares nothing with it and carries no Hash default, not cached;
  - nil, an empty string, a missing options row or any other value as a new empty indifferent hash on each read, the #1297 options-row rule, asking `get_meta` for no default.

  Have the option writers update what `options` returns in place, dropping their private conversion helper, and update the comment of `options` to match. Verify that the section 1 examples pass, and that `spec/models/meta_spec.rb`, `spec/models/meta_pending_create_spec.rb` and `spec/models/meta_duplicate_rows_spec.rb` pass.
- [x] 2.2 In `docs/ai/ecosystem.md`, add to the `camaleon-ecommerce` row its `set_meta('_default', params[:options])` options, read back with `get_option`, after confirming them in that repository. Verify the table still renders one row per repository.

## 3. Verification and delivery

- [x] 3.1 Run the CI-parity commands from `AGENTS.md` and verify all four pass: `bin/rspec`, `bin/rubocop` (auto-correct only touched files), `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 Commit the specs, fix and docs, push `fix/same-instance-option-reads`, and open the PR with a What and Why summary and a User-Visible Impact sentence (`docs/ai/workflows.md` Phase 4). Verify the PR's CI run starts.
- [x] 3.3 Add a `CHANGELOG.md` entry under `## Unreleased` linking the PR, with its detail in a note under "Notes for theme & plugin developers" in `docs/upgrading-to-2.9.5.md`, and verify the entry, its upgrade-notes link included, is at most 500 characters.
- [x] 3.4 Run `/opsx:verify` and address its findings.
- [x] 3.5 Run `/opsx:archive` on the branch, syncing both requirements into `openspec/specs/meta-storage-integrity/spec.md`. Commit it with the changelog entry, using the skip-ci directive once the PR has had a full run (`docs/ai/workflows.md` Phase 3), and verify every box in this file is checked.
