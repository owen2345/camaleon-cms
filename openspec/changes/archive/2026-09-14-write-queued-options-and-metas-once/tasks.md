## 1. Branch

- [x] 1.1 On `fix/save-data-options-once`, the PR #1299 branch (verify: `git branch --show-current`)

## 2. Implement (each with the spec that failed before it)

- [x] 2.1 The concern's after_create writes a post type's queues; its defaults fill in afterwards, under the options it holds (verify: `spec/models/post_type_spec.rb`, `spec/models/meta_data_options_spec.rb` pending-meta example)
- [x] 2.2 A queued container that is not a set of fields is refused in before_save (verify: `spec/models/meta_data_options_spec.rb` container example)
- [x] 2.3 Metas are written before options, through set_metas and set_options, with the metas scope rebuilt on create (verify: the `_default` meta example)
- [x] 2.4 The decorator validation reads the `_default` meta queued in data_metas (verify: `spec/models/camaleon_cms/post_type_decorator_class_spec.rb`)
- [x] 2.5 A save rolled back after the write queues the values again (verify: the rollback examples)
- [x] 2.6 A write on a record with loaded metas takes the row from them (verify: `spec/models/meta_duplicate_rows_spec.rb`)
- [x] 2.7 The two hooks are removed and the callbacks name save_metas_options (verify: `grep -rn save_metas_options_skip app` is empty)

## 3. Documentation

- [x] 3.1 `CHANGELOG.md` entry under 500 characters with the upgrade-guide anchor; `docs/upgrading-to-2.9.5.md` developer note; `docs/ai/ecosystem.md` and `docs/security/permissions.md` updated

## 4. Verify and close out

- [x] 4.1 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
- [x] 4.2 Delta specs synced into `openspec/specs/` and the change archived on the branch
