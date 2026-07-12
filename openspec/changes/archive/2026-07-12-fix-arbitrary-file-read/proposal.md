## Why

An authenticated user with "manage media" capability (not an admin) can read any server-side file the Rails process can access by sending `file_upload=/etc/hostname` to `POST /admin/media/upload` and omitting the `formats` parameter. The file content is copied into `public/media/{site_id}/hostname` and served publicly. This is CVSS 7.7 (High). The same pattern exists through `GET /admin/media/crop` with `cp_img_path=/etc/passwd`.

## What Changes

- Validate string file paths before opening them: only paths within `Rails.public_path` or `Dir.tmpdir` are allowed
- Fix the format validation bypass where omitting `formats` (nil) causes `validate_file_format` to return true for any file
- Apply both fixes in both files that contain the duplicated implementation (`runtime_uploader_concern.rb` and `uploader_helper.rb`)
- Add request-level specs that reproduce the attack and verify the fix

## Capabilities

### New Capabilities

- `upload-path-security`: Safe file upload source validation — the system MUST reject file uploads that reference server file paths outside of controlled temporary directories. This covers both the `upload_file` and `cama_tmp_upload` sinks.

### Modified Capabilities

- (none — `upload-content-security` covers content scanning, this is a separate concern)

## Impact

- `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` — add path prefix validation before `File.open(String)` in `upload_file` and `cama_tmp_upload`; fix format default handling
- `app/helpers/camaleon_cms/uploader_helper.rb` — same changes in the duplicate implementation
- `app/uploaders/camaleon_cms_uploader.rb` — optionally update `validate_file_format` default behavior for defense-in-depth
- `spec/requests/admin/media_controller/upload_spec.rb` — new test cases for file read attack
- `spec/requests/admin/media_controller/crop_spec.rb` — new test cases for path traversal via crop
- `spec/helpers/uploader_helper_spec.rb` — new tests for string path rejection
