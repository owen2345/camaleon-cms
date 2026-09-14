## 1. Branch

- [x] 1.1 On `fix/meta-cache-dup-and-reload`, the PR #1301 branch (verify: `git branch --show-current`)

## 2. Implement (each with the spec that failed before it)

- [x] 2.1 A copy starts without the original's memo, without the record of its last write and with queues of its own (verify: `spec/models/camaleon_record_cache_spec.rb` dup examples, `spec/models/meta_data_options_spec.rb` copy examples)
- [x] 2.2 `cama_clear_cache` names the reset and the three sites call it (verify: `grep -rn 'cama_cache_vars = nil' app` lists only the helper)
- [x] 2.3 `reload(options = nil)` drops the memo after `super`, forwards the lock option and rebuilds the ability and the user role (verify: `spec/models/camaleon_record_cache_spec.rb` reload examples; `grep -rn reset_ability app spec docs` is empty)
- [x] 2.4 A boolean reads back as the boolean and the hashes in a stored array by either key type (verify: `spec/models/meta_spec.rb` round-trip examples)
- [x] 2.5 `Site#get_languages` reads through the meta memo (verify: `spec/models/site_spec.rb` languages examples)
- [x] 2.6 A post reads the request's user and site from `CurrentRequest`; the `PostDefault` class attributes are gone (verify: `spec/controllers/concerns/camaleon_cms/request_context_concern_spec.rb`, the post permission example in `spec/models/camaleon_record_cache_spec.rb`; `grep -rn "cattr_accessor :current" app` is empty)
- [x] 2.7 The memo specs read before they reload, explain the priming read, and build on the shared post type; the options-row spec reads through `reload` (verify: the two spec files)

## 3. Documentation

- [x] 3.1 `CHANGELOG.md` entry under 500 characters with the upgrade-guide anchor; `docs/upgrading-to-2.9.5.md` developer note; `docs/MIGRATION_SELECT_EVAL.md` names `reload`

## 4. Verify and close out

- [x] 4.1 `bin/rspec`, `bin/rubocop`, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` all pass (verify: exit codes)
- [x] 4.2 Delta specs synced into `openspec/specs/` and the change archived on the branch
