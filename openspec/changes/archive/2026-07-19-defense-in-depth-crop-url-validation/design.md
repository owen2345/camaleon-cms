## Context

The `crop` action in `CamaleonCms::Admin::MediaController` accepts `params[:cp_img_path]` and passes it directly to `cama_tmp_upload`. The sibling `crop_url` action (in the `actions` method) validates URLs through `UserUrlValidator.validate(user_url, reject_path_traversal: true)` before calling `cama_tmp_upload`. The `crop` action has no equivalent check, creating an inconsistency.

While internal guards in `cama_tmp_upload` (`cama_canonical_upload_path`) currently prevent path traversal via `File.expand_path` and root-boundary checks, the `crop` action should validate at the controller level for defense-in-depth, matching the pattern established by `crop_url`.

## Goals / Non-Goals

**Goals:**
- Add URL validation to the `crop` action for HTTP/HTTPS URLs, matching `crop_url` behavior
- Use the existing `UserUrlValidator.validate` with `reject_path_traversal: true`
- All existing behavior for valid inputs preserved

**Non-Goals:**
- No changes to `cama_tmp_upload` or shared security modules
- No changes to non-URL inputs (local paths, data URIs) — those are handled by existing guards
- No new external dependencies

## Decisions

**Decision 1: Extract a shared `cama_upload_url_error` helper in the concern, called by all three upload entry points.**
The core validation logic lives in `cama_upload_url_error` in `RuntimeUploaderConcern` so that `crop`, `crop_url`, and `upload` all use identical validation. The decision to validate (and the render of the error) still happens at the controller level — the helper just avoids duplicating the `UserUrlValidator` parameter tuning across three actions.

**Decision 2: Use `UserUrlValidator.validate` with `reject_path_traversal: true`, tuning options for same-site vs remote URLs.**
For **same-site URLs** (detected by `same_site_url?`), the helper passes `resolve: false, enforce_sanitizing: false, enforce_user: false, allow_localhost: true, allow_local_network: true` — this skips DNS/SSRF checks because the file is read from the local filesystem, but still checks path traversal. For **remote URLs**, full validation (DNS resolution, SSRF guards, HTML sanitization) runs via the default parameters.

**Decision 3: Only validate HTTP/HTTPS URLs.**
Non-URL inputs (absolute paths, data URIs) cannot have hostnames and are handled by other means:
- Absolute paths → `cama_canonical_upload_path` catches path traversal
- data URIs → `File.basename` strips directory components from the name parameter

## Risks / Trade-offs

- **[Low] Same-site URLs skip DNS resolution**: The helper distinguishes same-site from remote URLs. Same-site URLs are read from the local filesystem, so SSRF/DNS checks would be irrelevant — the lighter validation (`resolve: false, allow_localhost: true`) prevents false rejection of legitimate local URLs and is safe because the file is only read, not fetched remotely.
- **[Very Low] Behavior change for invalid URLs**: Previously, an invalid URL would reach `cama_tmp_upload` and return `"Invalid file path"`. With this change, it will return the `UserUrlValidator` error message instead. This is a more informative error and the contract is unchanged for valid inputs.
