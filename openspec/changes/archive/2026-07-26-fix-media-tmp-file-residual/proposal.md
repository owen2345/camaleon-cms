## Why

When the upload content scanner rejects a file, `upload_file` returns the error `'Potentially malicious content found!'` — but the attacker's bytes have *already* been written to `public/tmp/<site_id>/` by `cama_tmp_upload`, and nothing deletes them. That directory is statically served, so a user holding only the `media` permission can plant `public/tmp/<site_id>/x.html` containing `<script>` and have it served same-origin at `/tmp/<site_id>/x.html`, defeating the very scan that reported the upload as rejected. This directly violates the existing `upload-content-security` requirement that a rejected upload "does NOT persist the file".

Reproduced on `master` (HEAD `15d3c1b9`) as a media-only user via `POST /admin/media/actions` with `media_action=crop_url`: response body was `Potentially malicious content found!` while `public/tmp/1/stored_xss.html` was left on disk containing the full payload.

The same leak occurs on every other early return in `upload_file` and `cama_tmp_upload` — format rejected, size exceeded, invalid folder — which leave benign content behind and grow `public/tmp/` without bound.

**The staging write is also unbounded.** `filesystem_max_size` (default 100 MB) is checked in `upload_file` only *after* staging. `cama_tmp_upload` has its own size check, but it is gated on `args[:maximum].present?` and neither `crop` nor `crop_url` passes `:maximum` — so it is dead code on the media controller paths. The remote-download branch bounds its body before writing; the `data:` branch does not. A media-permission user can therefore have an arbitrarily large base64 payload decoded and written to disk before any limit applies.

Separately, the regex denylist that decides what counts as malicious is incomplete. Twelve bypasses were confirmed empirically against the current `SUSPICIOUS_PATTERNS`, spanning three classes: encoding (HTML entities, tab/newline/NUL inside a URI scheme), missing schemes (`vbscript:`), and missing dangerous elements (`meta` refresh, `style`, `form`, `applet`, `frame`/`frameset`) plus a too-narrow tag delimiter that lets `<script/src=…>` through.

All of these were found while triaging an external RCE report against v2.9.2; the reported RCE itself is already fixed, these residuals are not.

## What Changes

- **Scan content before the staging write.** `cama_tmp_upload` will scan the decoded `data:` payload and the downloaded remote body with the content-security checker *before* writing them into the web-served staging directory, so hostile bytes never reach a servable path at all. Measurement showed the decoded payload is already fully materialized in memory at that point, so this adds no copies.
- **Bound the payload before decoding.** The `data:` branch will reject an oversized upload by estimating decoded size from the base64 length, before `Base64.decode64` runs. `args[:maximum]` will default to the site's `filesystem_max_size` so the existing — currently dead — size check in `cama_tmp_upload` starts working.
- **Clean up staged files on every failure path.** When `cama_tmp_upload` or `upload_file` returns an error after a staging file has been created, that file is removed. Deletion is guarded so it can only ever remove paths inside the staging root. This remains a necessary second layer: the pre-write checks cannot cover errors that are only detectable after staging, such as an invalid destination folder.
- **Complete the content denylist.** Normalize content before matching — decode HTML entities with a bounded loop, strip NUL and control characters, strip whitespace injected inside a URI scheme — so the encoding class of bypasses is closed structurally rather than pattern-by-pattern. Add `vbscript:` to the blocked schemes, widen the tag delimiter from `[\s>]` to `[\s/>]`, and add the missing dangerous elements. The scanner continues to fail closed.
- All changes are applied to `RuntimeUploaderConcern` and the parallel `UploaderHelper` copy through shared modules under `lib/camaleon_cms/`, consistent with how `UploaderPathSecurity` and `UploaderContentSecurity` are shared today.
- Regression specs: a request spec proving hostile content never appears under `public/tmp/`, per-error-path cleanup specs, a success-path spec proving the staged file is *not* deleted, a pre-decode size-bound spec, and one spec per confirmed denylist bypass.

## Capabilities

### New Capabilities
- `upload-staging-lifecycle`: Governs what may be written to the upload staging directory and how long it survives — that oversized content is rejected before it is decoded or written, that a staged file is removed whenever the upload it belongs to fails for any reason, that a successful upload retains it for the caller, and that cleanup can never delete outside the staging root.

### Modified Capabilities
- `upload-content-security`: Scanning is required to happen before the staging write rather than after it, with a content-based entry point alongside the existing IO-based one. The "does NOT persist the file" guarantee is tightened to explicitly cover the staging copy. Detection is strengthened with pre-match normalization, the `vbscript:` scheme, a widened tag delimiter, and additional dangerous elements.

## Impact

**Code**
- `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` — `cama_tmp_upload`, `upload_file`
- `app/helpers/camaleon_cms/uploader_helper.rb` — the parallel `cama_tmp_upload` / `upload_file` copies
- `lib/camaleon_cms/uploader_path_security.rb` — home for the guarded staging-cleanup helper
- `lib/camaleon_cms/content_security.rb` — `SUSPICIOUS_PATTERNS` and a new normalization step
- `lib/camaleon_cms/uploader_content_security.rb` — content-based scan entry point, normalization before matching

**Specs**
- New regression coverage under `spec/requests/admin/media_controller/` and for `CamaleonCms::ContentSecurity`

**Behavioral risk**
- Normalization makes the scanner stricter, so some previously-accepted uploads will now be rejected. The known case is a document containing HTML-escaped code examples (`&lt;script&gt;`), which after entity decoding matches the `<script` pattern. This is fail-closed and accepted; see design.md.
- Activating the `filesystem_max_size` bound on the `data:` branch means large uploads that previously succeeded through `crop_url` will now be rejected. This restores the documented, intended limit rather than introducing a new one.
- `cama_tmp_upload` is a documented public helper used by plugins and themes. Its success-path return contract — a readable file under `public/tmp/` — is unchanged.

**Not in scope**
- Widening `CamaleonCms::MediaSecurityHeaders` beyond SVG. Rejected: `Content-Security-Policy` on all `/media/` responses would break host apps that intentionally serve active content from the media directory. `media-serving-security` is unchanged by this proposal.
- Replacing the denylist with an extension allowlist. Rejected: it changes which uploads are accepted. Completing the denylist is the chosen approach.
- Relocating the staging directory out of `public/`. Rejected: plugins and themes may rely on the staged file being reachable by URL.
