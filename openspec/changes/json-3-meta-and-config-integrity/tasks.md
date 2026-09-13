## 1. Dependency pin

- [x] 1.1 Require json `< 3` in `camaleon_cms.gemspec`, the root `Gemfile` and every `gemfiles/*.gemfile`; verify `Gemfile.lock` lists `json (< 3)` with no PLATFORMS or CHECKSUMS change

## 2. Meta storage (`meta-storage-integrity`)

- [x] 2.1 Option writers work on an indifferent options hash and `set_meta` caches the caller's value; verify the `spec/models/meta_spec.rb` examples "stores a String-keyed option once after Symbol-keyed defaults", "deletes an option whichever key type wrote it", "reads the first String-keyed option of a record back by Symbol" and "keeps the hash a caller passed to set_meta" pass
- [x] 2.2 Serialize Hash and Array metas and custom-field values with one entry per key; verify "stores a hash meta with one entry per key however each key was written" in `spec/models/meta_spec.rb` and `spec/models/custom_field_value_json_spec.rb` pass (both failed on json 2 before the change)
- [x] 2.3 Read a stored meta that repeats a key with its last value; verify "reads the last value of the repeated key without a warning" in `spec/models/meta_spec.rb` passes
- [x] 2.4 Write and read the lowest-id row for a key with several rows; verify `spec/models/meta_duplicate_rows_spec.rb` passes
- [x] 2.5 Update a meta built before the first save instead of duplicating it on create; verify `spec/models/meta_pending_create_spec.rb` passes

## 3. Config loading (`config-json-loading`)

- [x] 3.1 Parse the system, plugin and theme configs accepting comments and repeated keys; verify the "config loading" examples in `spec/lib/plugin_routes_spec.rb` pass for the host system config, an app plugin, an app theme, a plugin gem and a theme gem
- [x] 3.2 Keep the shipped configs plain JSON; verify `spec/lib/shipped_json_configs_spec.rb` passes, and fails for a generator template given a comment

## 4. Documentation

- [x] 4.1 Update `docs/installation.md` (settings table), `docs/hooks.md` (gem plugin `key` rule), the dependency section of `docs/upgrading-to-2.9.5.md` (json pin and plugin floors, stated once) and the `cama_meta_tag` row of `docs/ai/ecosystem.md`; verify every anchor they link resolves
- [x] 4.2 Keep one `CHANGELOG.md` entry for PR #1292; verify it stays within 500 characters including its upgrade-notes line

## 5. Close out

- [ ] 5.1 Run `bin/rubocop`, `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`, push the branch, and verify the PR #1292 CI matrix passes
- [ ] 5.2 Update the PR #1292 description so it covers the net change
- [ ] 5.3 Run `/opsx:verify` and address its findings
- [ ] 5.4 Run `/opsx:archive` on the branch before merge, syncing both capabilities into `openspec/specs/`, and commit the archive in the PR
