## Context

`upload_file` and `cama_tmp_upload` both call `File.open(uploaded_io)` when `uploaded_io` is a `String`. This was designed for two legitimate cases: HTTP/HTTPS URL downloads and paths returned by internal temp-file methods. However, there is no validation that the string path is safe before opening it, allowing an attacker to read arbitrary server files via `params[:file_upload]` (upload action, no CSRF) or `params[:cp_img_path]` (crop action, GET-triggerable).

The vulnerable code is duplicated identically in two files:
- `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` (controller path, included in `CamaleonController`)
- `app/helpers/camaleon_cms/uploader_helper.rb` (view/helper path)

Additionally, when `params[:formats]` is omitted, `settings[:formats]` becomes `nil`, which overrides the default `'*'` via `.merge!` and causes `validate_file_format` to return `true` (because `nil.blank?` is true), bypassing extension validation entirely.

## Goals / Non-Goals

**Goals:**
- Prevent `File.open(String)` from operating on attacker-controlled paths outside system temp directories
- Fix the format validation bypass so omitting `formats` does not allow all files
- Cover both `upload_file` and `cama_tmp_upload` sinks
- Apply to both duplicated implementations

**Non-Goals:**
- No changes to the upload API contract (params remain the same)
- No changes to the file storage pipeline, thumbnail generation, or S3 uploader
- No changes to the content security scanner (that is a separate vulnerability)

## Decisions

**Decision 1: Path prefix validation before File.open**

Approach: Before `File.open(uploaded_io) if uploaded_io.is_a?(String)`, check that the path starts with `Rails.public_path.to_s` or `Dir.tmpdir`.

| Alternative | Verdict |
|---|---|
| Prefix validation on `Rails.public_path` and `Dir.tmpdir` | **Chosen** — covers all legitimate callers, minimal code change |
| Reject all absolute paths | Rejected — `cama_tmp_upload` returns absolute paths under `Rails.public_path/tmp/` |
| Move format check before File.open | Rejected — treats symptom, not root cause; format-allowed extensions still exploitable |
| Require Tempfile objects instead of strings | Rejected — API-breaking, plugin-incompatible |

Legitimate callers produce paths in these prefixes:
- `cama_download_remote_file` → `Dir.tmpdir + "/cama-upload-url*"`
- `cama_tmp_upload` → `Rails.public_path + "/tmp/{site_id}/"`
- `cama_crop_image` / `cama_resize_and_crop` → same dir as input (already within allowed prefixes)

**Decision 2: Fix format validation bypass**

In `upload_file`, after the `.merge!` of settings, coerce `settings[:formats]` to `'*'` if nil:

```ruby
settings[:formats] = '*' if settings[:formats].nil?
```

This ensures omitting `formats` falls back to the documented default `'*'` instead of bypassing validation.

## Risks / Trade-offs

- **[False positive: legitimate temp paths rejected]** → Any legitimate string path will start with one of the allowed prefixes because the system generates temp files under `Rails.public_path/tmp/` (via `cama_tmp_upload`) or `Dir.tmpdir` (via `cama_download_remote_file`). Low risk.
- **[Symlink escape in public/tmp]** → If an attacker can write symlinks in `Rails.public_path/tmp/`, they could point to `/etc/passwd`. However, write access to that directory requires media management privileges, which already allows uploading arbitrary files. Acceptable risk.
- **[Code duplication persists]** → The two implementations (`controller/concern` and `helper`) remain duplicated. Extracting the shared logic into a single module is out of scope for this security fix.
