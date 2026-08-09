## Why

The 2026-08 regression audit batched the upload-pipeline findings as PR 6 (N2, M26, M25, M24,
M28). N2 is a security gap exposed by the permission-gated scan; the rest are a config-dependent
crash, scan cost, a dead hook, and a doc gap.

- **N2** — `before_upload` (a hook handlers use to rewrite bytes, e.g. `camaleon_image_optimizer`
  running SVGO) fires **after** the content scan, and the file finally written is
  `settings[:uploaded_io]`, which the handler may have replaced. So for an untrusted uploader the
  scanned bytes need not be the persisted bytes — a handler can launder a blocked payload past
  the scanner. This is exactly the "content substituted after the check" case the
  `security-capability-gating` capability already requires be re-checked.
- **M26** — `cama_size_limit_error` treats a stored `filesystem_max_size` of `0` as a real
  limit (`0 >= size` is false for any non-empty file), so a site with the setting blank/zeroed
  fails **every** upload and crop with "File size exceeded (0 Bytes)". `cama_contact_form` reads
  the same option and passes it as `maximum:`, so coercing only core's read sites would miss it.
- **M25** — the content scan runs ~60 regexes (58 event-handler patterns in a loop plus the
  element and scheme patterns) over the full buffer; on a 100 MB upload that is seconds of CPU,
  and crop pays it twice. The 58 event patterns collapse to one alternation with identical
  matching.
- **M24** — media-manager (controller) upload errors never run the `on_translation` hook: the
  pipeline's `cama_uploader_ct` is a hard `I18n.t`, and only `UploaderHelper` overrides it —
  `RuntimeUploaderConcern` does not, even though controllers now carry `ct` (restored by #1223).
  Contradicts #1212's changelog claim.
- **M28** — dropping a plugin/theme folder then activating it requires a server restart now
  (#1163, deliberate); undocumented.

## What Changes

- **N2**: after `before_upload`, when the uploader is not permitted to skip scanning, re-scan
  `settings[:uploaded_io]` **only if the hook replaced it** (detected by object identity across
  the hook). A permission-holder still skips scanning as today; every other role has the
  rewritten bytes re-checked. Implements the `security-capability-gating` re-check requirement.
- **M26**: a non-positive `maximum` (`<= 0`) in `cama_size_limit_error` means unlimited — the
  single read point every caller (core and `cama_contact_form`) flows through.
- **M25**: the 58 event-handler patterns become one alternation regex (matching unchanged);
  the file is read/scanned once via the existing entry points. Behavior-preserving.
- **M24**: `RuntimeUploaderConcern` overrides `cama_uploader_ct` to route through `ct` when the
  host responds to it (running `on_translation`), falling back to `I18n.t` for non-controller
  includers. Amends the `uploader-implementation-parity` message-pipeline requirement.
- **M28**: changelog note that folder-drop discovery needs a restart.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `upload-content-security`: a `before_upload` handler that replaces the scanned IO for an
  untrusted uploader has its substituted bytes re-scanned (N2).
- `upload-staging-lifecycle`: a non-positive configured size limit is treated as unlimited (M26).
- `uploader-implementation-parity`: the controller entry point routes upload messages through
  `ct` when available, so `on_translation` fires there too (M24).

## Impact

- `lib/camaleon_cms/uploader_pipeline.rb` (`upload_file` re-scan, `cama_size_limit_error`),
  `lib/camaleon_cms/content_security.rb` (regex consolidation),
  `app/controllers/concerns/camaleon_cms/runtime_uploader_concern.rb` (`cama_uploader_ct`),
  `CHANGELOG.md`.
- Specs: new `spec/requests/security/upload_before_upload_rescan_spec.rb`,
  `spec/lib/camaleon_cms/upload_size_limit_spec.rb`,
  `spec/lib/camaleon_cms/runtime_uploader_translation_spec.rb`; extension to the content-security
  spec for the consolidated patterns.
- No routes or schema changes. Behavior deltas: laundering bytes past the scan via `before_upload`
  is closed for untrusted uploaders; a zero/blank size setting no longer blocks all uploads;
  media-manager upload errors are plugin-overridable; scans are cheaper.
