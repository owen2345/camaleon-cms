## Why

`CamaleonCms::RuntimeUploaderConcern` (364 RuboCop-countable lines) and `CamaleonCms::UploaderHelper` (354) are byte-identical except for three translation call sites, one settings-normalization line, and one concern-only method. Every upload security fix of the last three releases had to be written twice, and `Metrics/ModuleLength` has been ratcheted up three times to accommodate the pair (339 → 364).

The archived `fix-media-tmp-file-residual` change (Decision 4c) established that collapsing the two into one entry point does **not** work — `config/initializers/custom_initializers.rb` documents host apps doing `include CamaleonCms::UploaderHelper` inside an ActiveJob, where `helper_method` exposure would not reach — and deferred the workable direction to its own change: push the shared bodies down into `lib/camaleon_cms/` modules that both include, exactly as `UploaderPathSecurity` and `UploaderContentSecurity` already do. This is that change.

## What Changes

- Extract the 349 duplicated lines into three new modules under `lib/camaleon_cms/`, split so that no single module approaches the `ModuleLength` ceiling:
  - `UploaderPipeline` (~196 lines) — `upload_file`, `cama_tmp_upload`, and the private `cama_stage_data_uri`, `cama_download_remote_file`, `validate_file_format_or_error`, `cama_size_limit_error`.
  - `UploaderImageProcessing` (~101) — `cama_crop_image`, `cama_resize_and_crop`, `cama_resize_upload`, `cama_uploader_generate_thumbnail`, and the private `cama_crop_offsets_by_gravity`, `clamp_to_image_dimension`.
  - `UploaderSupport` (~61) — `cama_uploader`, `uploader_verify_name`, `cama_file_path_to_url`, `cama_url_to_file_path`, `slugify`, `slugify_folder`.
- Reduce both host modules to thin shims that `include` the three: `RuntimeUploaderConcern` keeps only `cama_upload_url_error` (~16 lines), `UploaderHelper` keeps only its seam overrides (~15 lines).
- Introduce a three-method **message seam** so the two contexts keep their current, different message pipelines: the shared modules call `cama_upload_common_t`, `cama_upload_t`, and `cama_upload_human_size`, which default to `I18n` / `ActiveSupport::NumberHelper` and are overridden in `UploaderHelper` to route through `ct` / `cama_t` / `number_to_human_size`. This preserves the `on_translation` hook that `ct` runs and a shared `I18n.t` call would silently drop.
- Source the `data:` staging filename guard from `args[:name]` instead of `params[:name]`. Identical on every controller path (the media controller passes `name: params[:name]`), and it removes the last request-context dependency from shared code, so the documented ActiveJob usage works for `data:` URIs instead of raising `NameError`.
- Reconcile the one accidental behavior divergence in `upload_file`: both entry points normalize `settings` with `to_h.deep_symbolize_keys` before assigning `:uploaded_io` (today the concern is shallow-and-mutating, the helper deep-and-non-mutating via the `lib/ext/hash.rb` `Hash#to_sym` monkeypatch, which `deep_symbolize_keys` replaces).
- Lower `Metrics/ModuleLength` in `.rubocop_todo.yml` from 364 to 326, and drop the now-unneeded `Naming/MethodParameterName` exclusion for `uploader_helper.rb`.

Non-goals: no change to the upload security guards themselves, to `UploaderPathSecurity` / `UploaderContentSecurity`, to the staging location, or to any public method name, arity, or return value.

## Capabilities

### New Capabilities
- `uploader-implementation-parity`: The two uploader entry points share one implementation, so behavior cannot drift between them; the seam that lets each keep its own message pipeline; and the requirement that `UploaderHelper` stays usable outside a request (standalone objects and ActiveJob).

### Modified Capabilities
- `upload-staging-lifecycle`: adds a requirement that the `data:` staging filename guard reads the caller's `:name` argument rather than request parameters, so `cama_tmp_upload` is callable outside a controller.

## Impact

**Code**
- New: `lib/camaleon_cms/uploader_pipeline.rb`, `lib/camaleon_cms/uploader_image_processing.rb`, `lib/camaleon_cms/uploader_support.rb`
- Modified: `lib/camaleon_cms.rb` (three `require`s), `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb`, `app/helpers/camaleon_cms/uploader_helper.rb`, `.rubocop_todo.yml`, `CHANGELOG.md`
- Specs: `spec/helpers/uploader_helper_spec.rb` (extend), plus a new parity spec

**Public API** — unchanged. Every method keeps its name, arity, visibility, and return contract, and stays reachable from both `include CamaleonCms::UploaderHelper` and any controller inheriting `CamaleonCms::CamaleonController`. Downstream plugin and theme gems that include `UploaderHelper` or call `cama_tmp_upload` / `upload_file` are unaffected; per `AGENTS.md` that ecosystem is not enumerable from this repo, which is why the shim modules must survive rather than be deleted.

**Behavior** — two intentional deltas, both spec-pinned: the `args[:name]` guard source, and the `settings` normalization reconciliation.
