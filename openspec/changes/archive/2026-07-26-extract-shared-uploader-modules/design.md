## Context

`RuntimeUploaderConcern` and `UploaderHelper` are two entry points onto one uploader. The concern is included by `CamaleonCms::CamaleonController` (and re-exported through `RuntimeStateConcern`); the helper is included by views, by standalone objects in specs, and — per `config/initializers/custom_initializers.rb` — by host-app ActiveJobs.

Stripped of comments and blank lines, the two files differ in exactly six places:

| # | Location | Concern | Helper |
|---|---|---|---|
| 1 | module head | `extend ActiveSupport::Concern` | `include ActionView::Helpers::NumberHelper`, `include CamaleonCms::CamaleonHelper` |
| 2 | `upload_file` | `settings[:uploaded_io] = io` then `settings.to_h.symbolize_keys` | `settings.to_sym` then `settings[:uploaded_io] = io` |
| 3 | `validate_file_format_or_error` | `I18n.t('camaleon_cms.common.file_format_error')` | `ct('file_format_error')` |
| 4 | `cama_stage_data_uri` | `I18n.t('camaleon_cms.admin.media.name_required')` | `cama_t('camaleon_cms.admin.media.name_required')` |
| 5 | `cama_size_limit_error` | `I18n.t(...)` + `ActiveSupport::NumberHelper.number_to_human_size` | `ct(...)` + `number_to_human_size` |
| 6 | `cama_upload_url_error` | present (11 lines, private) | absent |

Everything else — 349 RuboCop-countable lines across 18 methods — is byte-identical.

RuboCop-countable lines today, measured with `Metrics/ModuleLength` (`CountComments: false`):

| Group | Methods | Lines (each copy) |
|---|---|---|
| Pipeline | `upload_file` 69, `cama_tmp_upload` 64, `cama_download_remote_file` 30, `cama_stage_data_uri` 15, `cama_size_limit_error` 5, `validate_file_format_or_error` 4 | **187** |
| Image processing | `cama_resize_and_crop` 41, `cama_crop_image` 16, `cama_resize_upload` 15, `cama_crop_offsets_by_gravity` 15, `cama_uploader_generate_thumbnail` 10, `clamp_to_image_dimension` 4 | **101** |
| Support | `cama_uploader` 28, `uploader_verify_name` 15, `cama_file_path_to_url` 7, `slugify_folder` 5, `cama_url_to_file_path` 3, `slugify` 3 | **61** |
| Concern-only | `cama_upload_url_error` | 11 |
| Module head | includes / `private` | 4 (concern), 5 (helper) |
| | **Total** | **364** concern, **354** helper |

The archived `fix-media-tmp-file-residual` design (Decision 4c) ruled out collapsing the two into one entry point and named this extraction as the workable direction. Its constraint stands: **both `CamaleonCms::RuntimeUploaderConcern` and `CamaleonCms::UploaderHelper` must remain includable and behave as they do today**, because the downstream plugin and theme gems that include them are not enumerable from this repository (`AGENTS.md`, "Ecosystem").

## Goals / Non-Goals

**Goals:**
- One implementation of every duplicated method, so an upload fix can no longer land in one copy and not the other.
- Both entry points keep their exact public surface: same method names, arity, visibility, and return values.
- Each entry point keeps its own user-facing message pipeline, including the `on_translation` hook that `ct` runs.
- `UploaderHelper` remains usable with no request context — standalone objects and ActiveJob.
- Lower the `Metrics/ModuleLength` ceiling that this duplication has ratcheted up three times.

**Non-Goals:**
- Any change to the upload security guards, the denylist, the staging location, or `UploaderPathSecurity` / `UploaderContentSecurity`.
- Deleting either host module, or exposing one through the other via `helper_method` (settled in the archived Decision 4c).
- Consolidating `cama_upload_url_error` — it is not duplicated.
- Changing which uploads are accepted or rejected.

## Decisions

### Decision 1: Three shared modules, not one

Split the 349 lines into `UploaderPipeline` (187), `UploaderImageProcessing` (101), and `UploaderSupport` (61), all under `lib/camaleon_cms/`, all included by both hosts.

The split is forced, not stylistic. A single `UploaderCore` holding all 349 lines would itself be the longest module in the repository and `Metrics/ModuleLength` would have to stay near 364 — the duplication would be gone but the stated success criterion would not be met. Split three ways, the largest new module is ~196 lines and the ceiling is free to drop to 326, which is set by `app/helpers/camaleon_cms/admin/custom_fields_helper.rb` and has nothing to do with uploaders.

The boundaries follow call direction rather than convenience: `UploaderPipeline` calls into the other two, `UploaderImageProcessing` calls into `UploaderSupport`, and `UploaderSupport` calls into neither. No cycles.

`UploaderSupport` is honestly a leftovers bucket — backend resolution (`cama_uploader`) sits next to name and URL utilities. A tighter four-way split (`UploaderBackend` + `UploaderNaming`) was considered and rejected: it buys cohesion that nothing needs and adds a fourth file to require, load, and reason about, and 61 lines is small enough that the grouping costs nothing to read.

*Alternative considered:* extract only `upload_file` and `cama_tmp_upload` (187 lines), leaving the other 162 duplicated. Reaches the same 326 ceiling for a much smaller diff, but leaves two-thirds of the methods free to drift and would leave the next person asking why the line was drawn where it was.

### Decision 2: A three-method message seam, defaulting to `I18n`

The shared modules never call `ct`, `cama_t`, or `number_to_human_size` directly. They call three seam methods defined in `UploaderPipeline` with `I18n`-based defaults:

```ruby
# Seam: message rendering differs by execution context. The defaults here are what
# a controller gets — CamaleonController does not include CamaleonHelper, so `ct`
# is not defined there. UploaderHelper overrides all three to route through
# `ct`/`cama_t`, whose `on_translation` hook lets plugins override the text; a
# shared I18n.t call would silently drop that hook.
def cama_uploader_ct(key, args = {})     = I18n.t("camaleon_cms.common.#{key}", **args)
def cama_uploader_t(key, args = {})      = I18n.t(key, **args)
def cama_uploader_human_size(bytes)      = ActiveSupport::NumberHelper.number_to_human_size(bytes)
```

`UploaderHelper` overrides them as three one-liners delegating to `ct(key, args)`, `cama_t(key, args)`, and `number_to_human_size(bytes)`. The signatures deliberately mirror `ct`/`cama_t`'s own `(key, args = {})` so the overrides are pass-throughs with no adaptation.

Because `UploaderHelper` defines the overrides in its own body, they win over the included module for every ancestry arrangement — including a controller that ends up with both modules in scope.

Verified that the seam is genuinely required rather than historical accident: `CamaleonCms::CamaleonHelper` is included in exactly one place in the codebase, `UploaderHelper` itself. Controllers have no `ct`.

*Alternatives considered:*
- **Unify on `I18n.t` everywhere.** Rejected — silently removes the `on_translation` hook from the helper path, the exact regression the archived Decision 4c called out.
- **Unify on `ct` everywhere, by including `CamaleonHelper` into `RuntimeUploaderConcern`.** Rejected — pulls ~250 unrelated helper lines (`cama_edit_link`, `cama_sitemap_cats_generator`, …) onto every controller, and starts firing `on_translation` on controller upload paths where it never fired before. That is a behavior change to every host app's message text, dressed up as a refactor.
- **Inject a translator object** (`upload_message_translator` returning a lambda). Rejected — indirection with no benefit over template methods, which are what the rest of this codebase already uses.

### Decision 3: The `data:` name guard reads `args[:name]`, not `params[:name]`

`cama_stage_data_uri` currently guards on `params[:name].blank?` in **both** copies, then immediately uses `args[:name]`. Change the guard to `args[:name].blank?`.

On every in-repo path this is a no-op: `MediaController` calls `cama_tmp_upload(cp_img_path, formats: params[:formats], name: params[:name])`, so `args[:name]` *is* `params[:name]`.

Off that path it fixes two things. `params` is undefined in an ActiveJob, so the helper's `data:` branch raises `NameError` today despite `custom_initializers.rb` documenting exactly that usage — this makes it work. And a direct caller passing `name:` while `params[:name]` happens to be blank is currently rejected for a reason unrelated to its own arguments; conversely a caller with `params[:name]` set but `args[:name]` blank currently passes the guard and then builds a path from `File.basename('')`. Both become correct.

The alternative — keeping `params[:name]` and adding a fourth seam method for it — was rejected: it would enshrine a request-context dependency in shared code in order to preserve a latent bug, and the whole point of the extraction is that the shared code is context-free.

This is a behavior change, so per `AGENTS.md` it carries its own spec rather than riding on the refactor's behavior-preserving exemption.

### Decision 4: Reconcile `settings` normalization on `deep_symbolize_keys`

The shared `upload_file` uses:

```ruby
settings = settings.to_h.deep_symbolize_keys
settings[:uploaded_io] = uploaded_io
```

This keeps the helper's current *depth* and the helper's *ordering* — normalize first, so the caller's hash does not acquire an `:uploaded_io` key as a side effect — while replacing the `lib/ext/hash.rb` `Hash#to_sym` monkeypatch with the equivalent ActiveSupport idiom.

The equivalence was verified, not assumed. Both implement the same algorithm: recurse into nested Hashes and into Hashes nested inside Arrays, symbolizing keys along the way. For every realistic settings hash they produce `==` results. They diverge on exactly one input class — a key that cannot be symbolized, where `to_sym`'s bare `k.to_sym` raises `NoMethodError` while `deep_symbolize_keys`' `key.to_sym rescue key` leaves the key untouched. The replacement is therefore behavior-preserving for the helper and strictly more forgiving than what the helper does today.

The delta lands on the concern instead, which is shallow (`to_h.symbolize_keys`) today. It is unobservable for every key `upload_file` itself reads — `folder`, `maximum`, `formats`, `generate_thumb`, `temporal_time`, `filename`, `file_size`, `remove_source`, `same_name`, `versions`, `thumb_size`, `dimension` — all scalars; and both in-repo controller call sites (`MediaController` lines 38 and 116) pass flat hashes. It can only surface for caller-supplied nested data, or for a plugin hooking `before_upload`/`after_upload` that reads a nested key as a String.

*Alternatives considered:*
- **Shallow `symbolize_keys` on both**, matching the concern's current form. Rejected — it silently narrows behavior for `UploaderHelper`, the entry point with documented external includers (`custom_initializers.rb`) and standalone spec usage, in order to preserve the entry point whose callers are all inside this repository and all pass flat hashes. Deepening is also the safer direction of the two: a nested hash written as a Ruby literal is already symbol-keyed, so deep symbolization is a no-op on the idiomatic case, whereas shallow normalization breaks any caller that reads `settings[:nested][:key]`.
- **Seam it as a fourth overridable method.** Rejected — it would preserve a difference that no caller asked for and that neither side documents.
- **Keep calling `Hash#to_sym`.** Rejected — shared code under `lib/camaleon_cms/` should not depend on a `lib/ext` monkeypatch when a Rails core extension does the same job and handles a key type that `to_sym` raises on.

### Decision 5: Method visibility survives the split unchanged

`private` is per-module, so the public/private boundary has to be re-established in each new file: `UploaderPipeline` marks `cama_download_remote_file`, `validate_file_format_or_error`, `cama_stage_data_uri`, and `cama_size_limit_error` private; `UploaderImageProcessing` marks `cama_crop_offsets_by_gravity` and `clamp_to_image_dimension` private; `UploaderSupport` is entirely public; the concern keeps `cama_upload_url_error` private.

Cross-module calls are unaffected because every call is on an implicit receiver and all modules mix into the same object. Checked each one: `cama_tmp_upload` → `cama_resize_upload`/`uploader_verify_name`/`cama_uploader` (all public, other modules); `cama_resize_and_crop` → `uploader_verify_name` (public) plus its own two privates; `cama_resize_upload` → `cama_crop_image`/`cama_resize_and_crop` (same module, public).

The seam methods are public. They must be overridable from `UploaderHelper`'s body, and making them private would not prevent that but would misrepresent them — they are the documented extension point.

`spec/controllers/concerns/camaleon_cms/runtime_state_concern_spec.rb` already asserts that a bare class including `RuntimeStateConcern` responds to all 13 public uploader methods. It passes unchanged after the extraction (`respond_to?` resolves through ancestors) and is the regression guard for this decision; a mirror of it for `UploaderHelper` is added.

### Decision 6: Load the new modules by explicit `require`, and add `frozen_string_literal`

`lib/camaleon_cms.rb` already `require`s `uploader_content_security` and `uploader_path_security` explicitly rather than relying on autoloading; the three new files follow, keeping them loaded before any host module body evaluates its `include`.

All three get `# frozen_string_literal: true`, matching every other file in `lib/camaleon_cms/`. Checked the two in-place string mutations that move: `file.sub!('.svg', '.jpg')` and `settings[:output_name]&.sub!(...)` in `cama_resize_and_crop`. Neither touches a literal defined in the new file — `file` is a caller-supplied argument and `output_name` defaults to `+''`. This is confirmed rather than assumed: `uploader_helper.rb` already carries the magic comment today, so this code has been running under frozen literals in production for as long as the helper has existed.

### Decision 7: Phase the work one module at a time

`docs/ai/workflows.md` Phase 2C caps a refactor phase at five files. Each module extraction touches four (new file, `lib/camaleon_cms.rb`, concern, helper), so one module per phase, with `bin/rspec`, `bin/rubocop`, and `zeitwerk:check` between phases.

Phase 2C also mandates a Step-0 dead-code pass before restructuring any file over 300 LOC. Ran it: all 18 methods are reachable — `slugify_folder`, `cama_crop_image`, `cama_resize_upload` and the rest from `MediaController`, `cama_url_to_file_path` from `UserDecorator`, and the remainder are public API asserted by `runtime_state_concern_spec.rb`. Nothing to remove, so there is no separate cleanup commit.

## Risks / Trade-offs

- **A plugin helper that includes `UploaderHelper` gets mixed into `CamaleonController`** (via `PluginRoutes.all_helpers`), putting both modules in one ancestry → today the two full 187-line implementations compete and whichever was included last silently wins. After this change both resolve to the same `UploaderPipeline#upload_file` and only the seam differs; and when `UploaderHelper` is in the ancestry, `CamaleonHelper` comes with it, so `ct` is defined and its override is valid. The change strictly reduces this hazard rather than adding to it.
- **Downstream code reflecting on method ownership** → `CamaleonCms::UploaderHelper.instance_method(:upload_file).owner` changes, and `instance_methods(false)` no longer lists the moved methods. `alias_method`, `prepend`, `instance_method`, and reopening the module to redefine a method all continue to work, because they resolve through ancestors. Only `remove_method`/`undef_method` on a moved name would break, which is not a pattern this project has ever documented.
- **Shallow → deep `settings` symbolization for controller callers** (Decision 4) → unobservable for every key `upload_file` reads, and both in-repo call sites pass flat hashes. Would only surface for a caller passing a nested *string*-keyed hash through a controller and reading it back as a String, or for a plugin doing the same inside a `before_upload`/`after_upload` hook. A nested hash written as a Ruby literal is already symbol-keyed, so the idiomatic case is a no-op. Called out in the changelog.
- **`ct` requires `hooks_run`, which a bare `Class.new { include UploaderHelper }.new` does not have** → true today as well; the extraction must not route any previously-`I18n` path through `ct`, which the seam guarantees by defaulting to `I18n` and overriding only in `UploaderHelper`. The existing standalone specs exercise `same_site_url?` and `file_content_unsafe?`, neither of which translates.
- **Backporting future upload fixes to 2.9.x gets harder** → the file layout diverges from the 2.9.x branch, so a fix touching `upload_file` no longer applies cleanly. Accepted: this is the cost the archived Decision 4c deferred deliberately until after the security work shipped, which it now has.
- **Three new files to keep in `lib/camaleon_cms.rb`** → a missing `require` fails loudly at boot (`NameError` on the `include`), not subtly at upload time; `zeitwerk:check` runs in the per-phase verification.
- **The `args[:name]` change alters behavior for direct `cama_tmp_upload` callers** (Decision 3) → in the permissive direction only: inputs accepted today stay accepted. Spec-pinned and noted in the changelog.

## Migration Plan

No data migration, no schema change, no host-app configuration change. Public API is unchanged, so host apps upgrade without action.

Rollback is a straight revert of the phases in reverse order; nothing persists state that would outlive it.

## Open Questions

None. The two decisions that would have changed the shape of the work — extraction width and the `params[:name]` guard — were settled with the maintainer before this document was written and are recorded as Decisions 1 and 3.
