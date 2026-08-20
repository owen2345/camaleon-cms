## 1. Branch and reproduce

- [x] 1.1 Create branch `security/fix-media-tmp-file-residual` off `master`
- [x] 1.2 Add a failing request spec in `spec/requests/admin/media_controller/` proving the leak: as a media-only user, POST `crop_url` with a `data:` payload containing `<script>` and name `stored_xss.html`; assert the response reports `'Potentially malicious content found!'` AND that no file is created under `public/tmp/{site_id}/`
- [x] 1.3 Add a failing spec proving the `data:` branch is unbounded: a payload implying a decoded size above `filesystem_max_size` is currently written to `public/tmp/` before being rejected
- [x] 1.4 Add failing unit specs for the twelve confirmed denylist bypasses listed in `design.md` Decision 4, one example per bypass
- [x] 1.5 Confirm all of these fail on the current code for the right reason — file present, or content accepted — not from a setup error

## 2. Content scanning entry point

- [x] 2.1 In `lib/camaleon_cms/uploader_content_security.rb`, add `content_unsafe?(content, filename:)` holding the detection logic — `SvgContentChecker` when the filename ends in `.svg`, normalized pattern matching otherwise
- [x] 2.2 Reduce `file_content_unsafe?(uploaded_io)` to a wrapper that resolves the filename, reads the IO in binary, rewinds it, and delegates to `content_unsafe?` — preserving the existing rewind guarantee
- [x] 2.3 Add unit specs: same bytes scanned as String and via IO return the same verdict; SVG content passed as a String routes to the parse-based checker; the IO entry point still rewinds
- [x] 2.4 Confirm the existing `upload-content-security` and `svg-upload-sanitization` specs still pass unchanged

## 3. Bound and scan before the staging write

- [x] 3.1 In `RuntimeUploaderConcern#cama_tmp_upload`, default `args[:maximum]` to `current_site.get_option('filesystem_max_size', 100).to_f.megabytes` so the existing — currently dead — size check applies on the media controller paths
- [x] 3.2 In the `data:` branch, reject an oversized payload before `Base64.decode64` by estimating decoded size from the base64 length (`bytesize * 3 / 4`)
- [x] 3.3 In the `data:` branch, scan the decoded payload with `content_unsafe?` before the `File.open(path, 'wb')` write; return the existing `'Potentially malicious content found!'` error on rejection
- [x] 3.4 Apply the same pre-write scan to the downloaded remote body branch
- [x] 3.5 Mirror 3.1–3.4 in `app/helpers/camaleon_cms/uploader_helper.rb`
- [x] 3.6 Verify the specs from 1.2 and 1.3 now pass
- [x] 3.7 Add the size-bound specs from `upload-staging-lifecycle`: oversized rejected pre-decode, within-limit accepted, explicit `:maximum` still wins over the site option

## 4. Staging cleanup on failure

- [x] 4.1 Add a cleanup helper to `lib/camaleon_cms/uploader_path_security.rb` that deletes a path only after confirming via `path_within?` that it lies inside the staging root
- [x] 4.2 Add specs asserting the helper deletes inside the staging root and does NOT delete a path resolving outside it
- [x] 4.3 Wire cleanup into `RuntimeUploaderConcern#cama_tmp_upload` so a staged file is removed on every error return; extend the existing `ensure` block with an explicit error flag so the success path does NOT delete
- [x] 4.4 Wire cleanup into `RuntimeUploaderConcern#upload_file` so its early returns (content, format, size, invalid folder) remove the staged source — but only when `remove_source` is set
- [x] 4.5 Mirror 4.3 and 4.4 in `UploaderHelper`
- [x] 4.6 Add the remaining cleanup specs from `upload-staging-lifecycle`: format rejection, post-staging size rejection, invalid-folder rejection
- [x] 4.7 Add a spec asserting a successful `cama_tmp_upload` leaves the returned `:file_path` present and readable
- [x] 4.8 Add specs for the `remove_source` ownership boundary: caller-owned source survives a failed `upload_file`, uploader-owned staged source does not
- [x] 4.9 Add a spec exercising the `UploaderHelper` copy directly, so the two implementations cannot drift

## 5. Complete the content denylist

- [x] 5.1 In `lib/camaleon_cms/content_security.rb`, add a `normalize` step: HTML-entity decoding in a 5-pass break-when-stable loop matching `UserUrlValidator#validate_path_traversal`, NUL/control-character stripping, and removal of whitespace injected inside a URI scheme
- [x] 5.2 Widen the tag delimiter in the element patterns from `[\s>]` to `[\s/>]`
- [x] 5.3 Add `vbscript:` to the blocked schemes, aligning with `SvgContentChecker`
- [x] 5.4 Add the missing dangerous elements: `meta`, `style`, `form`, `applet`, `frame`, `frameset`, `link`, `template`, `portal`, `marquee`, `math`
- [x] 5.5 Apply `normalize` before matching in `content_unsafe?`
- [x] 5.6 Verify all twelve bypass specs from 1.4 now pass
- [x] 5.7 Add specs pinning the accepted false positive (HTML-escaped code examples are rejected) and the benign cases (plain text, CSV, JSON accepted)
- [x] 5.8 Add a spec asserting entity decoding stops after 5 passes rather than looping until stable
- [x] 5.9 **Found during implementation:** `UNSAFE_EVENT_PATTERNS` listed `onunloadonsubmit` as one token, so neither `onsubmit=` nor `onunload=` was ever matched. Split into two entries; specs added

## 6. Verification and delivery

- [x] 6.1 Run the full suite: `bin/rspec`
- [x] 6.2 Check for fallout from the stricter scanner and the newly-active size limit across existing fixtures and specs — any newly-rejected upload is either a genuine catch or a false positive needing a design.md note (**result:** no fallout; 720 examples, 0 failures, no existing fixture newly rejected)
- [x] 6.3 Run `bin/rubocop -A` on touched files only
- [x] 6.4 Run `bin/brakeman --no-pager`
- [x] 6.5 Run `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 6.6 Add a CHANGELOG entry under `## Unreleased` covering the pre-write scan, the newly-enforced `filesystem_max_size` on `data:` uploads, the cleanup fix, the stricter denylist and its false-positive consequence, and the operator note to clear stale `public/tmp/` contents on upgrade — crediting Lukman Azri, per `design.md` Resolved Questions
- [x] 6.7 Self-audit against `docs/ai/criteria.md` — passes on all headings. Commit/PR deferred: the maintainer is committing the `AGENTS.md` / `README.md` doc changes together with this fix
