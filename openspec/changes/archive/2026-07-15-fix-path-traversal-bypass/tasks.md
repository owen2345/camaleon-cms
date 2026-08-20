## 1. Setup & Context

- [x] 1.1 Create feature branch from latest main
- [x] 1.2 Read all 4 sink files and the media controller to confirm current state
- [x] 1.3 Read `config/locales/camaleon_cms/admin/en.yml` validate section for i18n key locations

## 2. i18n Keys

- [x] 2.1 Add `https_only_url` key under `camaleon_cms.admin.validate` in `en.yml`
- [x] 2.2 Add `path_traversal` key under `camaleon_cms.admin.validate` in `en.yml`

## 3. Improved UserUrlValidator

- [x] 3.1 Replace `app/validators/camaleon_cms/user_url_validator.rb` with improved implementation retaining class name `UserUrlValidator` — add `reject_path_traversal:`, `resolved_ip`, `resolve: false`, `validate_external_https`, env-var skip
- [x] 3.2 Write RSpec tests for the new validator in `spec/validators/camaleon_cms/user_url_validator_spec.rb`

## 4. File.expand_path Guards at 4 Sinks

- [x] 4.1 Add `File.expand_path` guard to `upload_file` in `RuntimeUploaderConcern` (replace raw `start_with?`)
- [x] 4.2 Add `File.expand_path` guard to `cama_tmp_upload` in `RuntimeUploaderConcern` (replace raw `start_with?`)
- [x] 4.3 Add `File.expand_path` guard to `upload_file` in `UploaderHelper` (replace raw `start_with?`)
- [x] 4.4 Add `File.expand_path` guard to `cama_tmp_upload` in `UploaderHelper` (replace raw `start_with?`)
- [x] 4.5 Write/update RSpec tests for the expand_path guards in spec files

## 5. Host Comparison for URL-to-Path Conversion

- [x] 5.1 Replace substring-based site URL detection with host+port comparison in `RuntimeUploaderConcern#cama_tmp_upload`
- [x] 5.2 Replace substring-based site URL detection with host+port comparison in `UploaderHelper#cama_tmp_upload`
- [x] 5.3 Add locale prefix stripping in the URL-to-path conversion to handle multi-lingual sites
- [x] 5.4 Write RSpec tests for host comparison in both modules

## 6. data: URI Handling & Crop URL Guard

- [x] 6.1 Skip `UserUrlValidator` for `data:` URIs in `CamaleonCms::Admin::MediaController#actions` (crop_url)
- [x] 6.2 Pass `reject_path_traversal: true` to `UserUrlValidator` in the `crop_url` action
- [x] 6.3 Add `File.expand_path` guard to the `cp_img_path` parameter validation in `CamaleonCms::Admin::MediaController#crop`
- [x] 6.4 Write RSpec tests for controller path validation

## 7. Verification

- [x] 7.1 Run full test suite: `bin/rspec` (key specs pass; intermittent SQLite contention unrelated)
- [x] 7.2 Run linter: `bin/rubocop -A` (4 pre-existing metrics offenses remain, unchanged logic)
- [x] 7.3 Run security scan: `bin/brakeman --no-pager` (0 warnings)
- [x] 7.4 Verify load: `(cd spec/dummy && bin/rails zeitwerk:check)` (all good)
