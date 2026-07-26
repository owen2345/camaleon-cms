## 1. Pre-flight

- [x] 1.1 Confirm work is on branch `feature/extract-shared-uploader-modules` off latest `master`
- [x] 1.2 Record the baseline: `bin/rspec`, `bin/rubocop`, and `(cd spec/dummy && bin/rails zeitwerk:check)` all green before any edit
- [x] 1.3 Record baseline `Metrics/ModuleLength` counts (concern 364, helper 354, next-highest `admin/custom_fields_helper.rb` 326) so the final ceiling change is verifiable
- [x] 1.4 Confirm the Phase-2C Step-0 dead-code pass finds nothing removable — every one of the 18 methods is reachable from `MediaController`, `UserDecorator`, or `runtime_state_concern_spec.rb` (design Decision 7); no separate cleanup commit is needed

## 2. Extract `UploaderPipeline` (files: 4)

- [x] 2.1 Create `lib/camaleon_cms/uploader_pipeline.rb` with `# frozen_string_literal: true`, `require 'net/http'`, `require 'tempfile'`, and a module comment stating that both uploader entry points include it
- [x] 2.2 Move `upload_file` and `cama_tmp_upload` into it verbatim as public methods, keeping the existing explanatory comments from whichever copy carries them
- [x] 2.3 Move `cama_download_remote_file`, `validate_file_format_or_error`, `cama_stage_data_uri`, and `cama_size_limit_error` in below a `private` keyword, preserving their current visibility
- [x] 2.4 Add the three public seam methods — `cama_uploader_ct(key, args = {})`, `cama_uploader_t(key, args = {})`, `cama_uploader_human_size(bytes)` — defaulting to `I18n.t("camaleon_cms.common.#{key}", **args)`, `I18n.t(key, **args)`, and `ActiveSupport::NumberHelper.number_to_human_size(bytes)`, with the comment from design Decision 2 explaining why the seam exists
- [x] 2.5 Replace the three translation/formatting call sites in the moved bodies with seam calls (`validate_file_format_or_error` → `cama_uploader_ct`, `cama_stage_data_uri` → `cama_uploader_t`, `cama_size_limit_error` → `cama_uploader_ct` + `cama_uploader_human_size`)
- [x] 2.6 Reconcile the `settings` normalization in `upload_file` to `settings = settings.to_h.deep_symbolize_keys` followed by `settings[:uploaded_io] = uploaded_io` (design Decision 4)
- [x] 2.7 Keep the `params[:name]` guard in `cama_stage_data_uri` unchanged for now, so this phase is a pure move plus the seam
- [x] 2.8 Add `require 'camaleon_cms/uploader_pipeline'` to `lib/camaleon_cms.rb`
- [x] 2.9 Delete the six methods from `RuntimeUploaderConcern` and add `include UploaderPipeline`
- [x] 2.10 Delete the six methods from `UploaderHelper`, add `include UploaderPipeline`, and add the three one-line seam overrides delegating to `ct`, `cama_t`, and `number_to_human_size`
- [x] 2.11 Verify: `bin/rspec`, `bin/rubocop`, `(cd spec/dummy && bin/rails zeitwerk:check)`

## 3. Extract `UploaderImageProcessing` (files: 4)

- [x] 3.1 Create `lib/camaleon_cms/uploader_image_processing.rb` with `# frozen_string_literal: true` and a `# rubocop:disable Naming/MethodParameterName` / `enable` pair covering the `w`/`h` parameters
- [x] 3.2 Move `cama_uploader_generate_thumbnail`, `cama_crop_image`, `cama_resize_and_crop`, and `cama_resize_upload` in as public methods
- [x] 3.3 Move `cama_crop_offsets_by_gravity` and `clamp_to_image_dimension` in below a `private` keyword
- [x] 3.4 Add `require 'camaleon_cms/uploader_image_processing'` to `lib/camaleon_cms.rb`
- [x] 3.5 Delete the six methods from `RuntimeUploaderConcern`, add the `include`, and remove its now-unnecessary file-level `# rubocop:disable Naming/MethodParameterName`
- [x] 3.6 Delete the six methods from `UploaderHelper` and add the `include`
- [x] 3.7 Verify: `bin/rspec`, `bin/rubocop`, `(cd spec/dummy && bin/rails zeitwerk:check)`

## 4. Extract `UploaderSupport` (files: 4)

- [x] 4.1 Create `lib/camaleon_cms/uploader_support.rb` with `# frozen_string_literal: true`, holding `cama_uploader`, `uploader_verify_name`, `cama_file_path_to_url`, `cama_url_to_file_path`, `slugify`, and `slugify_folder`, all public
- [x] 4.2 Add `require 'camaleon_cms/uploader_support'` to `lib/camaleon_cms.rb`
- [x] 4.3 Delete the six methods from `RuntimeUploaderConcern` and add the `include`; confirm only `cama_upload_url_error` and the includes remain
- [x] 4.4 Delete the six methods from `UploaderHelper` and add the `include`; confirm only the includes and the three seam overrides remain, and that the file's leading documentation comment for `upload_file` moves to `UploaderPipeline` rather than being lost
- [x] 4.5 Verify: `bin/rspec`, `bin/rubocop`, `(cd spec/dummy && bin/rails zeitwerk:check)`

## 5. Behavior change: caller-supplied staging name

- [x] 5.1 Change the `cama_stage_data_uri` guard in `UploaderPipeline` from `params[:name].blank?` to `args[:name].blank?` (design Decision 3)
- [x] 5.2 Confirm no remaining reference to `params` exists anywhere in the three shared modules

## 6. Specs

- [x] 6.1 Add `spec/lib/camaleon_cms/uploader_implementation_parity_spec.rb` asserting that the moved methods are absent from `instance_methods(false)` / `private_instance_methods(false)` on both host modules, and that `instance_method(:upload_file).owner` is `CamaleonCms::UploaderPipeline` from both entry points
- [x] 6.2 In the same spec, assert `cama_upload_url_error` is still defined directly on `RuntimeUploaderConcern` and absent from `UploaderHelper`
- [x] 6.3 Assert visibility parity: the four `UploaderPipeline` and two `UploaderImageProcessing` privates are private through both entry points, and the 12 public methods are public through both
- [x] 6.4 Mirror the uploader block of `spec/controllers/concerns/camaleon_cms/runtime_state_concern_spec.rb` for a bare class including `CamaleonCms::UploaderHelper`; leave the existing concern spec untouched so it keeps guarding the controller surface
- [x] 6.5 Add a spec proving the helper's size-limit message runs through `ct`: stub `hooks_run` so the `on_translation` hook sets `r[:flag]`/`r[:translation]`, then assert the returned error carries the hook's text
- [x] 6.6 Add the counterpart spec proving the concern's size-limit message renders from `I18n` without requiring `ct` to be defined, and that both entry points report the same human-readable limit
- [x] 6.7 Add a spec for the no-request-context requirement: an object including `UploaderHelper` that defines `current_site` but has no `params` stages a `data:` URI passed with `name:` without raising `NameError`
- [x] 6.8 Add specs for the staging name source: `cama_tmp_upload` with a `data:` URI and no `:name` returns the name-required error and stages nothing; with `:name` it stages under that name
- [x] 6.9 Add or confirm a request spec that `crop_url` with a blank `name` parameter still returns the name-required error, pinning the unchanged controller path
- [x] 6.10 Extend `spec/helpers/uploader_helper_spec.rb` with a case passing a `settings` hash containing string keys at the top level and inside a nested hash through `upload_file`, asserting both levels arrive symbolized at the `before_upload` hook — pinning the reconciled `deep_symbolize_keys` normalization for both entry points (design Decision 4)

## 7. Lint configuration and changelog

- [x] 7.1 Lower `Metrics/ModuleLength` in `.rubocop_todo.yml` from `Max: 364` to `Max: 326`, and refresh the offense-count comment above it
- [x] 7.2 Remove `'app/helpers/camaleon_cms/uploader_helper.rb'` from the `Naming/MethodParameterName` `Exclude` list, and refresh its offense-count comment
- [x] 7.3 Confirm no new `.rubocop_todo.yml` entry is needed for the three new files
- [x] 7.4 Draft the `CHANGELOG.md` entry at the top of `## Unreleased`, covering the extraction, the `args[:name]` guard change, and the note that `upload_file` now deep-symbolizes `settings` on the controller path as well as the helper path (design Risks)
- [x] 7.5 After opening the PR, replace the `(PR link pending)` marker in the changelog entry with the real `[#NNNN](https://github.com/owen2345/camaleon-cms/pull/NNNN)` reference, per `docs/ai/workflows.md` Phase 4 step 3

## 8. Final verification

- [x] 8.1 `bin/rspec` — full suite green
- [x] 8.2 `bin/rubocop` — clean with the lowered ceiling; auto-correct only files this change touched
- [x] 8.3 `bin/brakeman --no-pager` — no new warnings (the moved code includes the upload security sinks)
- [x] 8.4 `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 8.5 Confirm the measured line counts match the design: `UploaderPipeline` ≈ 196, `UploaderImageProcessing` ≈ 101, `UploaderSupport` ≈ 61, concern ≈ 16, helper ≈ 15
- [x] 8.6 Diff-review both host modules to confirm no method was dropped, renamed, or changed visibility, and that `git diff` shows only moves plus the changes named in design Decisions 2, 3, and 4
- [x] 8.7 Self-audit against `docs/ai/criteria.md` before opening the PR
