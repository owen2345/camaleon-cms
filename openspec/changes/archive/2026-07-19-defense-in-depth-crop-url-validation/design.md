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

**Decision 1: Validate at the controller level, not in the concern.**
The validation should mirror `crop_url`'s pattern exactly: check in the action before the delegation call. This keeps the defense close to the entry point and consistent within the same controller. Adding it to `cama_tmp_upload` would be redundant (the canonicalization guard already lives there) and would alter a shared method used by multiple callers.

**Decision 2: Use `UserUrlValidator.validate` with `reject_path_traversal: true`.**
This is the same validator and option used by `crop_url`. It catches `..` segments in the URL path, including percent-encoded forms like `%2e%2e`. Reusing the same call ensures consistent behavior between the two actions.

**Decision 3: Only validate HTTP/HTTPS URLs.**
Non-URL inputs (absolute paths, data URIs) cannot have hostnames and are handled by other means:
- Absolute paths → `cama_canonical_upload_path` catches path traversal
- data URIs → `File.basename` strips directory components from the name parameter

## Risks / Trade-offs

- **[Low] Double validation for same-origin URLs**: When `cp_img_path` is a same-origin HTTP URL, it will be validated in `crop` and then again inside `cama_tmp_upload`'s `cama_download_remote_file` path (if the URL is classified as remote). This is acceptable — validation is cheap and defense-in-depth is the goal.
- **[Very Low] Behavior change for invalid URLs**: Previously, an invalid URL would reach `cama_tmp_upload` and return `"Invalid file path"`. With this change, it will return the `UserUrlValidator` error message instead. This is a more informative error and the contract is unchanged for valid inputs.
