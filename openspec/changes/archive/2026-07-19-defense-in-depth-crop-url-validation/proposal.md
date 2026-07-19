## Why

The `crop` action in `MediaController` passes `params[:cp_img_path]` directly to `cama_tmp_upload` without validating whether it's a legitimate URL. The sibling `crop_url` action validates URLs through `UserUrlValidator.validate(user_url, reject_path_traversal: true)` before calling `cama_tmp_upload`, creating an inconsistency. While internal guards in `cama_tmp_upload` currently prevent path traversal, adding validation at the controller level provides consistent defense-in-depth and protects against future changes to the shared upload path logic.

## What Changes

- Extract `cama_upload_url_error` shared helper in `RuntimeUploaderConcern` that uses `UserUrlValidator` with path traversal detection
- `CamaleonCms::Admin::MediaController#crop` calls the shared helper before delegating to `cama_tmp_upload`, forwarding `formats` and `name` params
- `crop_url` and `upload` actions refactored to use the same shared helper, replacing their inline validation
- Non-URL paths (file system paths, data URIs) are unaffected — they are handled by existing guards in `cama_tmp_upload`
- New specs for the `crop` action covering invalid URL rejection
- No breaking changes

## Capabilities

### New Capabilities
- `crop-url-validation`: The crop controller action validates user-supplied URLs before passing them to the temporary upload pipeline, matching the behavior of the crop_url action.

### Modified Capabilities

None — no existing spec-level requirements are changing.

## Impact

- **Affected code**: `app/controllers/camaleon_cms/admin/media_controller.rb` (crop, crop_url, and upload actions), `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` (new `cama_upload_url_error` helper)
- **Affected tests**: `spec/requests/admin/media_controller/crop_spec.rb` (new test cases)
- **No API changes**: The controller action's request/response contract is unchanged for valid input
- **No dependency changes**
