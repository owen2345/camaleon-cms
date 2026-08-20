## Why

The #1198 fix added a `start_with?` prefix guard to prevent arbitrary file reads via upload and crop endpoints, but the guard is bypassable. Because it checks the raw string without canonicalizing the path first, `../` segments after an allowed prefix (e.g., `/app/public/../config/secrets.yml`) pass the check while `File.open` resolves them to arbitrary locations. Two independent bypass paths exist: the `cp_img_path` parameter in the `crop` action, and the `crop_url` action's URL-to-path substitution in `cama_tmp_upload`. Both sinks also exist in the helper module, giving 4 guard locations. Third-party plugins call these methods as public API, so every guard must be independently robust.

## What Changes

- Replace the raw `start_with?` prefix check with `File.expand_path` + prefix check at all 4 sink guards (both `upload_file` and `cama_tmp_upload` in both `RuntimeUploaderConcern` and `UploaderHelper`)
- Replace substring-based URL-to-path conversion in `cama_tmp_upload` with proper host comparison + `File.expand_path`
- Replace `UserUrlValidator` with an improved version that adds path traversal detection (`reject_path_traversal: true`), resolves #1048 regression where `data:` URIs are blocked, uses env-var-guarded validation skip instead of `Rails.env.development?`, and exposes `resolved_ip` for callers
- Skip `UserUrlValidator` for `data:` URIs in the `crop_url` controller action
- Add i18n keys for `https_only_url` and `path_traversal` under existing `camaleon_cms.admin.validate.*` namespace
- Add a rescue for `ArgumentError`/`TypeError` from `File.expand_path` to reject hostile inputs (null bytes, nil) cleanly

## Capabilities

### New Capabilities

- `upload-path-security`: Guard all string-to-file operations with path canonicalization before prefix validation. Supersedes the archived `upload-path-security` spec from #1198 with corrected requirements.
- `url-traversal-detection`: Detect `../` path traversal in URLs during SSRF validation, with opt-in `reject_path_traversal` flag.

### Modified Capabilities

*(No existing active specs change — the affected spec from #1198 is archived.)*

## Impact

- **Files touched:**
  - `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` — 3 insertion points (upload_file guard, cama_tmp_upload HTTP branch, cama_tmp_upload guard)
  - `app/helpers/camaleon_cms/uploader_helper.rb` — 3 insertion points (same pattern)
  - `app/validators/camaleon_cms/user_url_validator.rb` — replace with improved implementation (retaining class name `UserUrlValidator`)
  - `app/controllers/camaleon_cms/admin/media_controller.rb` — `crop_url` action: skip validation for `data:` URIs, pass `reject_path_traversal: true`
  - `config/locales/camaleon_cms/admin/en.yml` — add `https_only_url` and `path_traversal` keys
  - Spec files for helpers, requests, and validators
- **API-compatible:** All public method signatures unchanged. Existing plugin calls to `upload_file` and `cama_tmp_upload` continue to work, but previously-bypassable path inputs are now correctly blocked.
- **No new dependencies.**
